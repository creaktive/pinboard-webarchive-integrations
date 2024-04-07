#!/usr/bin/env perl
use 5.020;
use feature qw(postderef signatures);
no warnings qw(experimental::postderef experimental::signatures);

use List::Util qw(shuffle);

use Mojo::File;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;
use Mojo::Util qw(url_escape);

use constant OUTPUT => 'webarchive.json';

sub main($input) {
    my $path = Mojo::File->new($input);
    my $pinboard = decode_json $path->slurp;

    my %seen;
    if (open(my $fh, '<:raw', OUTPUT)) {
        while (my $line = <$fh>) {
            my $data = decode_json $line;
            die "bad JSON: $line\n" unless exists $data->{url};
            ++$seen{$data->{url}};
        }
        close $fh;
    }

    my $ua = Mojo::UserAgent->new(inactivity_timeout => 0);
    for my $pin (shuffle $pinboard->@*) {
        next if exists $seen{$pin->{href}};
        next unless $pin->{href} =~ m{^https?://}x;

        ($pin->{time} =~ m{^([0-9]{4})-([0-9]{2})-([0-9]{2})}x)
            or die "can't parse time: @{[ $pin->{time} ]}\n";
        my $date = $1 . $2 . $3;

        my $url = 'https://archive.org/wayback/available'
            . '?url=' . url_escape($pin->{href})
            . '&timestamp=' . $date;

        say $url;
        my $result = $ua->get($url)->result;
        if ($result->is_success
            and 'HASH' eq ref eval { decode_json $result->body }
        ) {
            open(my $fh, '>>:raw', OUTPUT)
                or die "can't write to @{[ OUTPUT ]}: $@\n";
            say $fh $result->body;
            close $fh;

            sleep 5;
        } else {
            sleep 60;
            redo;
        }
    }

    return 0;
}

exit main(@ARGV);
