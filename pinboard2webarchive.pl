#!/usr/bin/env perl
use 5.020;
use feature qw(postderef signatures);
no warnings qw(experimental::postderef experimental::signatures);

use Mojo::Date;
use Mojo::UserAgent;
use Mojo::Util qw(url_escape);

use constant PINBOARD_RSS_URL => 'https://feeds.pinboard.in/rss/u:creaktive/';
use constant PROCESS_FROM => time - 3 * 86_400;

my $ua = Mojo::UserAgent->new(inactivity_timeout => 0);
my $from = Mojo::Date->new(PROCESS_FROM)->to_datetime;

my $result = $ua->get(PINBOARD_RSS_URL)->result;
for my $item (reverse $result->dom('item')->@*) {
    my $link = $item->at('link')->text;
    my $date = $item->at('date')->text;

    next if $date lt $from;
    $ua->get('https://web.archive.org/save/' . url_escape $link);
}

exit 0;
