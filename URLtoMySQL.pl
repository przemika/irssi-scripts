#!/usr/bin/perl -w
#
# $Id: urltomysql.pl,v 0.01 2012/04/20 13:59:51 rzemyk Exp $
#
# use at own risk, this is a VERY experimental code
#
# SQL dump of database schema
#
#       CREATE DATABASE urltomysql;
#
#       use urltomysql;
#
#       CREATE TABLE urltomysql (
#       IDurl int NOT NULL AUTO_INCREMENT,
#       attime datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
#       server varchar(65),
#       channel varchar(65),
#       nick varchar(15),
#       line varchar(255),
#       url varchar(255),
#       PRIMARY KEY (IDurl)
#       ) CHARSET=utf8;
#
# important: database name is hardcoded 
use strict;
use vars qw($VERSION $rcsid %IRSSI);
use POSIX qw(strftime);
use Irssi;
use Irssi::Irc;
use DBI();

$rcsid = '$Id: URLtoMySQL.pl,v 0.01 2012/04/20 13:59:51 rzemyk Exp $';
($VERSION) = $rcsid =~ /,v (\d+\.\d+) /;

%IRSSI = (
    authors     => 'Przemyslaw Mika',
    contact     => 'przemyslaw@mika.pro',
    name        => 'URLtoMySQL',
    description => 'Provides MySQL database with URLs pasted on your channels.',
    license     => 'BSD',
    url         => 'http://www.przemyslaw.mika.pro/download/irc/irssi/urltomsqyl',
    changed     => '$Date: 2012/04/20 13:59:51 $'
);

my $debug = 1;
my $max_items = 20;
my $url_title = 'URLs on $chan';
my $url_description = 'Database of URLs recently pasted on $chan $tag channel';
my $url_dbhost = '127.0.0.1';
my $url_dbname = 'urltomysql';
my $url_dbuser = 'urltomysql_pass';
my $url_dbpass = 'p@ssw0rd';


sub urltomysql_if_exist {
    my ($tag, $target, $nick, $text, $url) = @_;

    my $connect = DBI->connect("DBI:mysql:database=$url_dbname;host=$url_dbhost", $url_dbuser, $url_dbpass, {'RaiseError' => 1}) or die "unable to connect $DBI::errstr";
    my $inserter = $connect->prepare("SELECT url FROM urltomysql WHERE = (?)");
    $inserter->execute($url);
    $connect->disconnect();
}

sub urltomysql_add_to_db {
    my ($tag, $target, $nick, $text, $url) = @_;

    $nick = "guest" unless (defined $nick);
    $text = $url unless (defined $text);

    my $connect = DBI->connect("DBI:mysql:database=$url_dbname;host=$url_dbhost", $url_dbuser, $url_dbpass, {'RaiseError' => 1}) or die "unable to connect $DBI::errstr";
    my $inserter = $connect->prepare("INSERT INTO urltomysql (attime, server, channel, nick, line, url) VALUES (NOW(),?,?,?,?,?)");
    $inserter->execute($tag, $target, $nick, $text, $url);
    $connect->disconnect();
}

# based on urlgrab.pl by David Leadbeater
sub urltomysql_find_urls {
    my ($text) = @_;
    my @chunks = split(/[ \t]+/, $text);
    my @urls = ();
    foreach my $chunk (@chunks) {
        if($chunk =~ /((ftp|http|https):\/\/[a-zA-Z0-9\/\\\:\?\%\.\&\;=#\-\_\!\+\~\,]+)/i) {
            push(@urls, $1);
        } elsif ($chunk =~ /(www\.[a-zA-Z0-9\/\\\:\?\%\.\&\;=#\-\_\!\+\~\,]+)/i) {
            push(@urls, "http://" . $1);
        }
    }
    return @urls
}

# this part of script is based on urlfeed.pl by Jakub Jankowski
sub urltomysql_transfer {
    my ($tag, $target, $nick, $text) = @_;
    my @urls = urltomysql_find_urls($text);
    foreach my $url (@urls) {
        urltomysql_add_to_db($tag, $target, $nick, $text, $url);
    }
}

sub urltomysql_msg {
    my ($server, $text, $nick, $hostmask, $target) = @_;
    return unless ($target =~ /^[\!\#\&\+]/);
    urltomysql_transfer($server->{tag}, lc($target), $nick, $text);
}

sub urltomysql_msg_own {
    my ($server, $text, $target) = @_;
    return unless ($target =~ /^[\!\#\&\+]/);
    $target = '!' . substr($target, 6) if ($target =~ /^\!/);
    urltomysql_transfer($server->{tag}, lc($target), $server->{nick}, $text);
}

Irssi::settings_add_bool('urltomysql', 'urltomysql_debug',     $debug);
Irssi::settings_add_int ('urltomysql', 'urltomysql_max_items', $max_items);
Irssi::settings_add_str ('urltomysql', 'urltomysql_title',     $url_title);
Irssi::settings_add_str ('urltomysql', 'urltomysql_description', $url_description);

#Irssi::print("URLtoMySQL Loaded.");

Irssi::signal_add_last('message public',     'urltomysql_msg');
Irssi::signal_add_last('message own_public', 'urltomysql_msg_own')
