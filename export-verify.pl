#!/usr/bin/env perl
use 5.020;
use feature qw(postderef signatures);
no warnings qw(experimental::postderef experimental::signatures);

use List::Util qw(shuffle);

use Mojo::File;
use Mojo::JSON qw(decode_json);
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::Util qw(url_escape);

use constant OUTPUT => 'webarchive.json';
use constant BLACKLIST => [qw[
    archive.org
    bash.org.ru
    feedly.com
    feedproxy.google.com
    feeds.feedburner.com
    feeds.gawker.com
    rss.slashdot.org
    t.co
    twitter.com
    web.archive.org
    whiplash.net
    www.youtube.com
]];

sub main($input) {
    my $path = Mojo::File->new($input);
    my $pinboard = decode_json $path->slurp;

    my %blacklist = map { $_ => 1 } BLACKLIST->@*;
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
    $ua->proxy->https('socks://192.168.0.2:9050');
    say STDERR $ua->get('https://ifconfig.me/ip')->result->body;

    my @urls;
    for my $pin ($pinboard->@*) {
        my $href = Mojo::URL->new($pin->{href});
        next unless $href->protocol =~ m{^https?$}x;
        next if exists $blacklist{$href->host};
        next if exists $seen{$href};

        ($pin->{time} =~ m{^([0-9]{4})-([0-9]{2})-([0-9]{2})}x)
            or die "can't parse time: @{[ $pin->{time} ]}\n";
        my $date = $1 . $2 . $3;

        my $url = 'https://archive.org/wayback/available'
            . '?url=' . url_escape($href)
            . '&timestamp=' . $date;

         push @urls, $url;
    }

    printf STDERR "checking %d URLs\n", scalar @urls;
    my $c = 0;
    for my $url (shuffle @urls) {
        printf STDERR "%.1f%%\t", 100 * (++$c / scalar @urls);
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
            # redo;
        }
    }

    return 0;
}

exit main(@ARGV);
