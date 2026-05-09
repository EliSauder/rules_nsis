load("@bazel_skylib//lib:paths.bzl", "paths")

def _dirrule_impl(ctx):
  outdir = ctx.actions.declare_directory("{}.dir".format(ctx.attr.name))
  args = ctx.actions.args()
  args.add(outdir.path)

  for src in ctx.files.srcs:
      args.add(src)
      args.add(str(src.owner.name))

  ctx.actions.run_shell(
    outputs = [outdir],
    inputs = ctx.files.srcs,
    arguments = [args],
    command = """
outdir=$1;
shift;
mkdir -p "$outdir"
while [ "$#" -gt 0 ]; do
    src="$1"
    dst="$outdir/$2"
    shift 2
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
done
""",
  )
  return [DefaultInfo(files = depset([outdir]))]

dirrule = rule(
  implementation = _dirrule_impl,
  attrs = {
    "srcs": attr.label_list(
        allow_files = True,
        mandatory = True,
    ),
  },
)
