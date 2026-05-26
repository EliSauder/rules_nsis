load("@bazel_skylib//lib:paths.bzl", "paths")

def _dirrule_impl(ctx):
  outdir = ctx.actions.declare_directory("{}.dir".format(ctx.attr.name))
  args = ctx.actions.args()

  filecontent=""
  for src in ctx.files.srcs:
      args.add(src)
      args.add(str(src.owner.name))

      filecontent = filecontent + "{}\0{}\0".format(str(src.path), str(src.owner.name))

  argFile = ctx.actions.declare_file("{}-param-file".format(ctx.attr.name))
  ctx.actions.write(
      output = argFile,
      content = filecontent,
  )

  ctx.actions.run_shell(
    outputs = [outdir],
    inputs = ctx.files.srcs + [argFile],
    arguments = [outdir.path, argFile.path],
    command = """
outdir=$1
infile=$2
mkdir -p "$outdir"
while IFS= read -r -d '' key && IFS= read -r -d '' value
do
    src="$key"
    dst="$outdir/$value"
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
done < "$infile"
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
