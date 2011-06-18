0.2.0
=====

- Support overwrite detection and behaviors for the
  {HandBrake::CLI#output}.
- Support "atomic" output mode in {HandBrake::CLI#output}.

0.1.0
=====

- Change {HandBrake::Title#chapters} from an Array to a Hash. This is
  consistent with {HandBrake::Titles} and obviates the need for index
  to chapter number conversions. {HandBrake::Title#all_chapters} is
  the equivalent of the old {HandBrake::Title#chapters} method.

0.0.2
=====

- Add {HandBrake::Chapter#number}.

0.0.1
=====

- Initial release.
