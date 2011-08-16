HandBrake for Ruby
==================

This library provides a lightweight literate ruby wrapper for
[HandBrakeCLI][], the command-line interface for the [HandBrake][]
video transcoder.

[HandBrakeCLI]: https://trac.handbrake.fr/wiki/CLIGuide
[HandBrake]: http://handbrake.fr/

The intent of this library is to make it a bit easier to script
HandBrake. You will still need to be familiar with HandBrake and
HandBrakeCLI to make use of it.

Prerequisites
-------------

* [HandBrake][hb-dl] and [HandBrakeCLI][cli-dl] (tested with 0.9.5)
* Ruby and RubyGems (tested with Ruby 1.8.7 and 1.9.2)

[hb-dl]: http://handbrake.fr/downloads.php
[cli-dl]: http://handbrake.fr/downloads2.php

Installation
------------

handbrake.rb is distributed as a rubygem:

    $ gem install handbrake

Use
---

A brief sample:

    require 'handbrake'

    hb = HandBrake::CLI.new(:bin_path => '/Applications/HandBrakeCLI', :trace => false)

    project = hb.input('/Volumes/Arcturan Megafreighter/DVDs/L')

    disc = project.scan
    disc.titles[1].number              # => 1
    disc.titles[1].main_feature?       # => true
    disc.titles[1].duration            # => "01:21:18"
    disc.titles[1].seconds             # => 4878
    disc.titles[1].chapters.size       # => 23
    disc.titles[1].chapters[3].seconds # => 208

    project.title(1).
      preset('Normal').
      output('/Users/rsutphin/Movies/project.m4v')

In additional detail:

### Create a HandBrake::CLI instance

    require 'handbrake'

    hb = HandBrake::CLI.new(:bin_path => handbrake_cli_path, :trace => true)

This object carries the path to the HandBrakeCLI bin and other library
configuration options:

* `:bin_path`: the path to the `HandBrakeCLI` executable. The default
  is `'HandBrakeCLI'`; i.e., by default it will be searched for on the
  normal executable path.
* `:trace`: if true, all output from `HandBrakeCLI` will be echoed to
  the project's error stream.

### Set options

You build up a command string by invoking a chain of methods starting
from a `HandBrake::CLI` instance. The methods are named following the
long form of the options for [HandBrakeCLI][]. (The one exception to
this naming scheme is for options that contain a dash; in those cases,
an underscore must be substituted for the dash.)

E.g., the HandBrakeCLI documentation has this command:

    $ HandBrakeCLI -i /Volumes/MyBook/VIDEO_TS -o /Volumes/MyBook/movie.m4v -v -P -m -E aac,ac3 -e x264
      -q 0.65 -x ref=3:mixed-refs:bframes=6:b-pyramid=1:weightb=1:analyse=all:8x8dct=1:subme=7:me=umh
      :merange=24:filter=-2,-2:trellis=1:no-fast-pskip=1:no-dct-decimate=1:direct=auto

In handbrake.rb, you could build up this command like so:

    vid_opts = 'ref=3:mixed-refs:bframes=6:b-pyramid=1:weightb=1:analyse=all:8x8dct=1:subme=7:me=umh:merange=24:filter=-2,-2:trellis=1:no-fast-pskip=1:no-dct-decimate=1:direct=auto'
    HandBrake::CLI.new.input('/Volumes/MyBook/VIDEO_TS').verbose.
      loosePixelratio.markers.aencoder('aac,ac3').encoder('x264').
      quality('0.65').x264opts(vid_opts).
      output('/Volumes/MyBook/movie.m4v')

The `output` option has to go last; see the next section for more details.

### Starting execution

While most of the methods you call to build up a handbrake command can
come in any order, a few must come last and have particular return
values:

* `output`: triggers a transcode using all the options set up to this
  point. No return value.
* `scan`: triggers a title scan and returns either a {HandBrake::Disc}
  (for all titles) or a {HandBrake::Title} (for a single title).
* `update`: returns true or false depending on whether the version of
  HandBrakeCLI in use is up to date.
* `preset_list`: returns a hash containing all the known presets and
  their options. The structure is `presets[category][name] => args`.

### Reusing a configuration chain

At any point before invoking one of the execution methods (listed in
the previous section), you can save off the chain and continue it
along different paths.  E.g.:

    project = HandBrake::CLI.new.input('VIDEO_TS')

    # iPhone
    project.preset('iPhone & iPod Touch').output('project-phone.m4v')

    # TV
    project.preset('High Profile').output('project-tv.m4v')

To put it more technically, each intermediate configuration step
returns an independent copy of the configuration chain.

### Output options

By default, the `output` execution method behaves just like invoking
HandBrakeCLI directly. `handbrake.rb` also supports a couple of
additional behaviors, including overwrite detection and atomic output
file creation. See {HandBrake::CLI#output} for more details.

Additional resources
--------------------

* API docs: [last release](http://rubydoc.info/gems/handbrake) or
  [in development](http://rubydoc.info/github/rsutphin/handbrake.rb/master/frames)
* [Continuous integration](http://travis-ci.org/#!/rsutphin/handbrake.rb)
  (note that right now this link only works when there has been a
  recent build)
* Versioning policy: [Semantic versioning](http://semver.org/)
* [Bugs and feature requests](https://github.com/rsutphin/handbrake.rb/issues)

Patches
-------

Patches with tests will be happily reviewed. Please submit a pull
request from a topic branch in your own fork on GitHub.

License
-------

    handbrake.rb
    Copyright (C) 2011 Rhett Sutphin.

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.
