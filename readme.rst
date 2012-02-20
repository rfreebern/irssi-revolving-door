====================
Irssi Revolving Door
====================

Summarizes multiple consecutive joins/parts/quits/nick changes in a single channel by tracking them in a single line, increasing the signal-to-noise ratio in any channel and easily allowing you to see at a glance the current state of all changes to a channel's member list since anyone last spoke.

Example
-------

Turns this::

 11:38:28 -!- david [david@fake.host] has quit [Quit: Leaving.]
 11:47:14 -!- sarah [sarah@made.up.host] has joined #talk
 11:50:14 -!- marco [marco@some.pretend.host] has quit [Quit: Leaving...]
 11:52:45 -!- robin [robin@example.host] has quit [Quit: robin]
 11:53:07 -!- robin [robin@example.host] has joined #talk
 11:53:50 -!- harold [harold@fake.host] has joined #talk
 11:54:02 -!- courtney [courtney@my.pretend.host] has quit [Quit: courtney]
 12:02:54 -!- marco [marco@some.pretend.host] has joined #talk
 12:19:18 -!- harold is now known as harold|afk
 12:20:00 -!- sarah [sarah@made.up.host] has quit [Ping timeout]
 12:20:31 -!- marco is now known as marco_

into this::

 Joins: harold|afk -- Quits: david, courtney -- Nicks: marco -> marco_

But there's data loss!
----------------------

Yes. Consider it lossy compression. Do you really need to see all those masks and quit messages, anyway?

Installation and usage
----------------------

#. ``cd ~/.irssi/scripts && wget http://raw.github.com/rfreebern/irssi-revolving-door/master/revolve.pl``
#. In irssi, run ``/script load revolve.pl``
#. Want to autorun? ``ln -s ~/.irssi/scripts/revolve.pl ~/.irssi/scripts/autorun/``
