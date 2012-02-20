use Irssi;
use strict;
use Irssi::TextUI;
use vars qw($VERSION %IRSSI);

$VERSION = "0.0.1";
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

sub summarize {
    my ($server, $channel, $nick, $new_nick, $type) = @_;

    my $window = $server->window_find_item($channel);
    return if (!$window);
    my $view = $window->view();
    my $check = $server->{tag} . ':' . $channel;

    $view->set_bookmark_bottom('bottom');
    my $last = $view->get_bookmark('bottom');
    my $secondlast = $last->prev();

    # Remove the last line, which should have the join/part/quit message.
    $view->remove_line($last);

    # If the second-to-last line is a summary line, parse it.
    my %door = ('Joins' => [], 'Parts' => [], 'Quits' => [], 'Nicks' => []);
    my @summarized = ();
    if ($secondlast->{'_irssi'} == $summary_lines{$check}) {
        my $summary = Irssi::strip_codes($secondlast->get_text(1));
        @summarized = split(/ -- /, $summary);
        foreach my $part (@summarized) {
            my ($type, $nicks) = split(/: /, $part);
            $door{$type} = [ split(/, /, $nicks) ];
        }
        $view->remove_line($secondlast);
    }

    if ($type eq '__revolving_door_join') { # Join
        push(@{$door{'Joins'}}, $nick);
        @{$door{'Parts'}} = grep { $_ ne $nick } @{$door{'Parts'}} if (scalar @{$door{'Parts'}});
        @{$door{'Quits'}} = grep { $_ ne $nick } @{$door{'Quits'}} if (scalar @{$door{'Quits'}});
    } elsif ($type eq '__revolving_door_quit') { # Quit
        push(@{$door{'Quits'}}, $nick) if (!grep(/^$nick$/, @{$door{'Joins'}}));
        @{$door{'Joins'}} = grep { $_ ne $nick } @{$door{'Joins'}} if (scalar @{$door{'Joins'}});
    } elsif ($type eq '__revolving_door_part') { # Part
        push(@{$door{'Parts'}}, $nick) if (!grep(/^$nick$/, @{$door{'Joins'}}));;
        @{$door{'Joins'}} = grep { $_ ne $nick } @{$door{'Joins'}} if (scalar @{$door{'Joins'}});;
    } else { # Nick
        my $nick_found = 0;
        foreach my $known_nick (@{$door{'Nicks'}}) {
            my ($orig_nick, $current_nick) = split(/ -> /, $known_nick);
            if ($new_nick eq $orig_nick) { # Changed nickname back to original.
                @{$door{'Nicks'}} = grep { $_ ne "$orig_nick -> $current_nick" } @{$door{'Nicks'}};
                $nick_found = 1;
                last;
            } elsif ($current_nick eq $nick) {
                @{$door{'Nicks'}} = map { $_ =~ s/\b$current_nick\b/$new_nick/ } @{$door{'Nicks'}};
                $nick_found = 1;
                last;
            }
        }
        if (!$nick_found) {
            push(@{$door{'Nicks'}}, "$nick -> $new_nick");
        }
        # Update nicks in join/part/quit lists.
        foreach my $part (qw/Joins Parts Quits/) {
            @{$door{$part}} = map { $_ =~ s/^$nick$/$new_nick/ } @{$door{$part}} if (scalar @{$door{$part}});
        }
    }

    @summarized = ();
    foreach my $part (qw/Joins Parts Quits Nicks/) {
        if (scalar @{$door{$part}}) {
            push @summarized, "\%W$part:\%n " . join(', ', @{$door{$part}});
        }
    }

    my $summary = join(' -- ', @summarized);
    $window->print($summary, MSGLEVEL_NEVER);
    
    # Get the line we just printed so we can log its ID.
    $view->set_bookmark_bottom('bottom');
    $last = $view->get_bookmark('bottom');
    $summary_lines{$check} = $last->{'_irssi'};

    $view->redraw();
}

sub summarize_join {
    my ($server, $channel, $nick, $address, $reason) = @_;
    &summarize($server, $channel, $nick, 0, '__revolving_door_join');
}

sub summarize_quit {
    my ($server, $nick, $address, $reason) = @_;
    my @channels = $server->channels();
    foreach my $channel (@channels) {
        my $window = $server->window_find_item($channel->{name});
        next if (!$window);
        my $view = $window->view();
        $view->set_bookmark_bottom('bottom');
        my $last = $view->get_bookmark('bottom');
        my $last_text = $last->get_text(1);
        if ($last_text =~ m/$nick.*?has quit/) {
            &summarize($server, $channel->{name}, $nick, 0, '__revolving_door_quit');
        }
    }
}

sub summarize_part {
    my ($server, $channel, $nick, $address, $reason) = @_;
    &summarize($server, $channel, $nick, 0, '__revolving_door_part');
}

sub summarize_nick {
    my ($server, $new_nick, $old_nick, $address) = @_;
    my @channels = $server->channels();
    foreach my $channel (@channels) {
        my $channel_nick = $channel->nick_find($new_nick);
        if (defined $channel_nick) {
            &summarize($server, $channel->{name}, $old_nick, $new_nick, '__revolving_door_nick');
        }
    }
}

Irssi::signal_add_priority('message join', \&summarize_join, Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message part', \&summarize_part, Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message quit', \&summarize_quit, Irssi::SIGNAL_PRIORITY_LOW + 1);
Irssi::signal_add_priority('message nick', \&summarize_nick, Irssi::SIGNAL_PRIORITY_LOW + 1);
