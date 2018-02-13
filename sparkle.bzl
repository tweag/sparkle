"""Helpers for sparkle packaging."""

def _get_file_from_target(ctx, trgt, fname):
  for f in trgt.files:
    if f.basename == fname:
      return f
  fail("Could not find {0} in outputs of {1}".format(fname, trgt.label.name))

def _wrap_sparkle_impl(ctx):
  sparkle_jar = _get_file_from_target(
    ctx,
    ctx.attr.sparkle_jar_rule,
    "{0}.jar".format(ctx.attr.sparkle_jar_rule.label.name),
  )
  sparkle_hs = _get_file_from_target(
    ctx,
    ctx.attr.sparkle_hs_rule,
    ctx.attr.sparkle_hs_rule.label.name,
  )
  ctx.actions.write(
    output=ctx.outputs.executable,
    content=" ".join([
      sparkle_hs.path,
      "--sparkle-jar",
      sparkle_jar.path,
      '"$@"',
    ]),
    is_executable=True,
  )

  return [DefaultInfo(
    runfiles=ctx.runfiles(files=[sparkle_hs, sparkle_jar])
  )]

# Apply --sparkle-jar for the user ensuring that it's available in
# environment. I don't know if it does anything though because bazel
# run still doesn't like it
#
# https://github.com/bazelbuild/examples/blob/master/rules/runfiles/execute.bzl
wrap_sparkle_hs = rule(
  _wrap_sparkle_impl,
  executable = True,
  attrs = {
    "sparkle_hs_rule": attr.label(
      mandatory=True,
      doc="Haskell sparkle binary rule.",
    ),
    "sparkle_jar_rule": attr.label(
      mandatory=True,
      doc="Sparkle Java rule.",
    ),
  },
)
