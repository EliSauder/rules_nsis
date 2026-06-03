<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="nsis_toolchain"></a>

## nsis_toolchain

<pre>
load("@rules_nsis//nsis:toolchain.bzl", "nsis_toolchain")

nsis_toolchain(<a href="#nsis_toolchain-name">name</a>, <a href="#nsis_toolchain-args_style">args_style</a>, <a href="#nsis_toolchain-makensis">makensis</a>, <a href="#nsis_toolchain-nsis_dir">nsis_dir</a>, <a href="#nsis_toolchain-nsis_files">nsis_files</a>, <a href="#nsis_toolchain-path_style">path_style</a>)
</pre>

Defines an NSIS Bazel toolchain implementation.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="nsis_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="nsis_toolchain-args_style"></a>args_style |  The possible type of argument prefix. Slash for win and dash for unix.   | String | required |  |
| <a id="nsis_toolchain-makensis"></a>makensis |  makensis executable.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="nsis_toolchain-nsis_dir"></a>nsis_dir |  The directory for NSISDIR.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="nsis_toolchain-nsis_files"></a>nsis_files |  All NSIS distribution files.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="nsis_toolchain-path_style"></a>path_style |  The style of path that things should be output as.   | String | required |  |


