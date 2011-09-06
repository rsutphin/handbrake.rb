0.4.0
=====

- Allow the `:runner` option for {HandBrake::CLI} to take a lambda
  that returns the runner. (#4)
- Document the default runner to make the runner protocol
  explicit. (#4)
- Ensure that arguments that contain quotes are properly escaped
  during execution. (#2; reported by bmatsuo)

0.3.1
=====

- Add `:dry_run` option for {HandBrake::CLI}. When true, the commands
  that would be executed otherwise are printed to standard out
  instead.
- Ensure that the directories needed by a call to
  {HandBrake::CLI#output} exist before writing to them.
- Ensure that the options hash passed into #output is not modified.

0.3.0
=====

- Change the output from the `scan` action to be a {HandBrake::Disc}
  object which contains a titles hash, rather than the hash directly.
- When `scan`ning for a single title, return only a single
  {HandBrake::Title}.
- Accept a path for the `:atomic` option to
  {HandBrake::CLI#output}. If specified, the temporary file will be
  written to this path rather than the ultimate target directory.
- Ensure that trace mode prints updating lines (e.g., the encode
  status) that do not end in newlines in a timely fashion.
- Add property-based constructors to {HandBrake::Title} and
  {HandBrake::Chapter} for easier construction in tests of consuming
  apps/libs.

0.2.1
=====

- Include parent references in {HandBrake::Title} and
  {HandBrake::Chapter}.
- When parsing a title scan, do not keep references to the parsed tree
  in the {HandBrake::Title} objects.

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
