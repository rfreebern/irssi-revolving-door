use strict;
use warnings;
use Irssi;
use Irssi::TextUI;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.5"; # d145a98c82647ab
%IRSSI = (
    authors => 'Ryan Freebern',
    contact => 'ryan@freebern.org',
    name => 'revolve',
    description => 'Summarizes multiple sequential joins/parts/quits.',
    license => 'GPL v2 or later',
    url => 'http://github.com/rfreebern/irssi-revolving-door',
);

# Based on compact.pl by Wouter Coekaerts <wouter@coekaerts.be>
# http://wouter.coekaerts.be/irssi/scripts/compact.pl.html

my %summary_lines;

use constant {
    JOINS => +MSGLEVEL_JOINS,
    PARTS => +MSGLEVEL_PARTS,
    QUITS => +MSGLEVEL_QUITS,
    NICKS => +MSGLEVEL_NICKS
};


my %msg_level_text;

# all texts and all separators must be distinguishable and one must
# not be a substring of another!
@msg_level_text{(JOINS, PARTS, QUITS, NICKS)}=qw/Joins Parts Quits Nicks/;
my $level_separator = ' ── ';
my $nick_separator = ', ';
my $type_separator = ': ';
my $new_nick_separator = ' → ';

my %msg_level_constant = reverse %msg_level_text;

sub lrtrim {
    for (@_) {
        s/^\s+//; s/\s+$//;
    }
}

sub summarize {
    my ($window, $tag, $channel, $nick, $new_nick, $type) = @_;

    return unless $window;
    my $view = $window->view;
    my $check = $tag . ':' . $channel;

    my $tb = $view->get_bookmark('trackbar');
    $view->set_bookmark_bottom('bottom');
    my $last = $view->get_bookmark('bottom');
    if ($tb && $last->{_irssi} == $tb->{_irssi}) {
        $last = $last->prev;
    }
    my $secondlast = $last ? $last->prev : undef;
    if ($tb && $secondlast && $secondlast->{_irssi} == $tb->{_irssi}) {
        $secondlast = $secondlast->prev;
    }

    # Remove the last line, which should have the join/part/quit message.
    return unless $last->{info}{level} & $type;
    $view->remove_line($last);

    # If the second-to-last line is a summary line, parse it.
    my %door = (JOINS() => [], PARTS() => [], QUITS() => [], NICKS() => []);
    my @summarized = ();
    if ($secondlast and $summary_lines{$check} and $secondlast->{_irssi} == $summary_lines{$check}) {
        my $summary = $secondlast->get_text(0);
        lrtrim $summary;
        @summarized = split(/\Q$level_separator/, $summary);
        lrtrim @summarized;
        foreach my $part (@summarized) {
            my ($type, $nicks) = split(/\Q$type_separator/, $part, 2);
            lrtrim $nicks;
            $door{$msg_level_constant{$type}} = [ split(/\Q$nick_separator/, $nicks) ];
        }
        $view->remove_line($secondlast);
    }

    if ($type == JOINS) { # Join
        if (grep { $_ eq $nick } @{$door{+PARTS}}, @{$door{+QUITS}}) {
            @{$door{+PARTS}} = grep { $_ ne $nick } @{$door{+PARTS}};
            @{$door{+QUITS}} = grep { $_ ne $nick } @{$door{+QUITS}};
        } else {
            push(@{$door{+JOINS}}, $nick);
        }
    } elsif ($type == QUITS) { # Quit
        if (grep { $_ eq $nick } @{$door{+JOINS}}) {
            @{$door{+JOINS}} = grep { $_ ne $nick } @{$door{+JOINS}};
        } else {
            push @{$door{+QUITS}}, $nick;
        }
    } elsif ($type == PARTS) { # Part
        if (grep { $_ eq $nick } @{$door{+JOINS}}) {
            @{$door{+JOINS}} = grep { $_ ne $nick } @{$door{+JOINS}};
        } else {
            push @{$door{+PARTS}}, $nick;
        }
    } else { # Nick
        my $nick_found = 0;
        foreach my $known_nick (@{$door{+NICKS}}) {
            my ($orig_nick, $current_nick) = split(/\Q$new_nick_separator/, $known_nick);
            if ($new_nick eq $orig_nick) { # Changed nickname back to original.
                @{$door{+NICKS}} = grep { $_ ne $known_nick } @{$door{+NICKS}};
                $nick_found = 1;
                last;
            } elsif ($current_nick eq $nick) {
                $_ =~ s/\Q$new_nick_separator$current_nick\E$/$new_nick_separator$new_nick/ foreach @{$door{+NICKS}};
                $nick_found = 1;
                last;
            }
        }
        if (!$nick_found) {
            push(@{$door{+NICKS}}, "$nick$new_nick_separator$new_nick");
        }
        # Update nicks in join/part/quit lists.
        foreach my $part (JOINS, PARTS, QUITS) {
            $_ =~ s/^\Q$nick\E$/$new_nick/ foreach @{$door{$part}};
        }
    }

    @summarized = ();
    my $level = MSGLEVEL_NEVER;
    foreach my $part (JOINS, PARTS, QUITS, NICKS) {
        if (@{$door{$part}}) {
            push @summarized, '%I' . $msg_level_text{$part} . $type_separator . '%I'
                . join($nick_separator, @{$door{$part}});
            $level |= $part;
        }
    }

    my $summary = join($level_separator, @summarized);
    if (@summarized) {
        $window->print(' 'x10 . '%|%w'.$summary, $level);
        # Get the line we just printed so we can log its ID.
        $view->set_bookmark_bottom('bottom');
        $last = $view->get_bookmark('bottom');
        $summary_lines{$check} = $last->{_irssi};
    } else {
        delete $summary_lines{$check};
    }

    $view->redraw();
}

sub delete_and_summarize {
    return unless our @summary;
    my ($tag, $channel, $nick, $new_nick, $type) = @summary;
    my ($dest) = @_;
    return unless $dest->{server} && $dest->{server}{tag} eq $tag;
    return if defined $channel && $dest->{target} ne $channel;
    &Irssi::signal_continue;
    summarize($dest->{window}, $tag, $dest->{target}, $nick, $new_nick, $type);
}

sub summarize_join {
    my ($server, $channel, $nick, $address, $reason) = @_;
    local our @summary = ($server->{tag}, $channel, $nick, undef, JOINS);
    &Irssi::signal_continue;
}

sub summarize_quit {
    my ($server, $nick, $address, $reason) = @_;
    local our @summary = ($server->{tag}, undef, $nick, undef, QUITS);
    &Irssi::signal_continue;
}

sub summarize_part {
    my ($server, $channel, $nick, $address, $reason) = @_;
    local our @summary = ($server->{tag}, $channel, $nick, undef, PARTS);
    &Irssi::signal_continue;
}

sub summarize_nick {
    my ($server, $new_nick, $old_nick, $address) = @_;
    local our @summary = ($server->{tag}, undef, $old_nick, $new_nick, NICKS);
    &Irssi::signal_continue;
}

Irssi::signal_add('message join', 'summarize_join');
Irssi::signal_add('message part', 'summarize_part');
Irssi::signal_add('message quit', 'summarize_quit');
Irssi::signal_add('message nick', 'summarize_nick');
Irssi::signal_add('print text', 'delete_and_summarize');
