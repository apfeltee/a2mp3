
# `a2mp3` - anything2mp3

a2mp3 makes converting wma, ogg, etc to mp3 as easy as it gets!
It uses well established software, such as [mplayer](https://www.mplayerhq.hu/), [lame](http://lame.sourceforge.net/) and [ffmpeg](https://www.ffmpeg.org/) in an easy-to-use, portable [bash](http://www.gnu.org/software/bash/) script.

Using it is literally as easy as:

    a2mp3 audiofile.wma
    # output is written to audiofile.mp3

Batch conversion is just as easy:

    a2mp3 directory/full/of/wma/files/*.wma
    # the MP3 files are written in the same location!

If the program [`gettags`](http://kevinboone.net/README_gettags.html) (kevinboone.net) is in your $PATH, a2mp3 will automatically adopt the tags from the source file (if any). This program, gettags, supports flac, ogg, and mp3 formats.

a2mp3 is written to be easily extended, and the code is well commented. So if it's missing a feature you miss, adding it is trivial.
