<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="nsis"></a>

## nsis

<pre>
nsis = use_extension("@rules_nsis//nsis:extensions.bzl", "nsis")
nsis.executable(<a href="#nsis.executable-name">name</a>, <a href="#nsis.executable-version">version</a>)
</pre>


**TAG CLASSES**

<a id="nsis.executable"></a>

### executable

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="nsis.executable-name"></a>name |  Generating host-dispatching repository exposing :makensis and :nsis_files.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | optional |  `"nsis"`  |
| <a id="nsis.executable-version"></a>version |  The version of nsis to use.   | String | optional |  `"3.11"`  |


