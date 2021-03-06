GNATcoll Bindings - Readline: interactive command line
======================================================

.. highlight:: ada

GNATcoll provides an interface to the ``readline`` library.

.. sidebar:: License

   |Note| The GNU `readline` library is licensed under the terms of the GNU
   General Public License, version 3. This means that if you want to use
   Readline in a program that you release or distribute to anyone, the program
   must be free software and have a GPL-compatible license.

You need to pass ``--accept-gpl`` to the ``setup.py`` script in order to
indicate you understand the license of ``readline``.

This component provides various features to enhance command line support in
tools.  In particular, it provides various keybindings to make editing more
comfortable than ``Ada.Text_IO.Get_Line``. For instance, it is possible to use
backspace to edit what you have just typed. It is also possible to move forward
or backward by word, go to the start or end of line, ...

``readline`` also provides support for completion: by using the :kbd:`tab` key,
users can get all possible completions for the current word. This behavior is
controllable from Ada, where your application can provide the list of
completions.

Finally, readline comes with support for history. By using the :kbd:`up` and
:kbd:`down` keys, the user can navigate the commands that were previously
typed. It is also possible to preserve the history across sessions.

See the ``GNATCOLL.Readline`` package for more information on this API.
