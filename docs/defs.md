<!-- Generated with Stardoc: http://skydoc.bazel.build -->



<a id="nsis_component"></a>

## nsis_component

<pre>
load("@rules_nsis//nsis:defs.bzl", "nsis_component")

nsis_component(<a href="#nsis_component-name">name</a>, <a href="#nsis_component-srcs">srcs</a>, <a href="#nsis_component-dependencies">dependencies</a>, <a href="#nsis_component-description">description</a>, <a href="#nsis_component-directory">directory</a>, <a href="#nsis_component-display_name">display_name</a>, <a href="#nsis_component-install_categories">install_categories</a>,
               <a href="#nsis_component-selection_mode">selection_mode</a>, <a href="#nsis_component-service">service</a>, <a href="#nsis_component-service_args">service_args</a>, <a href="#nsis_component-service_dependencies">service_dependencies</a>, <a href="#nsis_component-service_executable">service_executable</a>,
               <a href="#nsis_component-service_start_type">service_start_type</a>, <a href="#nsis_component-shortcuts">shortcuts</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="nsis_component-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="nsis_component-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="nsis_component-dependencies"></a>dependencies |  A list of components this one depends on.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="nsis_component-description"></a>description |  The description of the component being installed.   | String | optional |  `""`  |
| <a id="nsis_component-directory"></a>directory |  The sub directory path under $INSTPATH where the component will be installed.   | String | optional |  `""`  |
| <a id="nsis_component-display_name"></a>display_name |  The display name for the component. Defaults to the rule name converted to Title Case.   | String | optional |  `""`  |
| <a id="nsis_component-install_categories"></a>install_categories |  The list of install types that the component will be included in.   | List of strings | optional |  `[]`  |
| <a id="nsis_component-selection_mode"></a>selection_mode |  Defines how the component shows up in the UI when selecting.<br><br>hidden: The component will always be installed and is hidden from the user. required: The compenent is visible to the user, but will always be selected. default: The component is optional but will be selected by default. optional: The component is optional but will be deselected by default.   | String | optional |  `"required"`  |
| <a id="nsis_component-service"></a>service |  Whether the component represents a windows service.   | Boolean | optional |  `False`  |
| <a id="nsis_component-service_args"></a>service_args |  Command line args to pass to the service executable.   | List of strings | optional |  `[]`  |
| <a id="nsis_component-service_dependencies"></a>service_dependencies |  Defines the list of windows services this service depends on.   | List of strings | optional |  `[]`  |
| <a id="nsis_component-service_executable"></a>service_executable |  The executable of the service. Required if service is True.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="nsis_component-service_start_type"></a>service_start_type |  Defines the start type to pass into sc.exe start field.   | String | optional |  `"auto"`  |
| <a id="nsis_component-shortcuts"></a>shortcuts |  A list of files that, when installed, will be created as shortcuts if short cuts are enabled.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="nsis_component_group"></a>

## nsis_component_group

<pre>
load("@rules_nsis//nsis:defs.bzl", "nsis_component_group")

nsis_component_group(<a href="#nsis_component_group-name">name</a>, <a href="#nsis_component_group-bold">bold</a>, <a href="#nsis_component_group-components">components</a>, <a href="#nsis_component_group-description">description</a>, <a href="#nsis_component_group-display_name">display_name</a>, <a href="#nsis_component_group-expanded">expanded</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="nsis_component_group-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="nsis_component_group-bold"></a>bold |  Whether the group name font is bolded in the UI.   | Boolean | optional |  `True`  |
| <a id="nsis_component_group-components"></a>components |  The list of components or component groups to be apart of this group.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="nsis_component_group-description"></a>description |  The description of the group.   | String | optional |  `""`  |
| <a id="nsis_component_group-display_name"></a>display_name |  The display name for the group. Defaults to the rule name converted to Title Case.   | String | optional |  `""`  |
| <a id="nsis_component_group-expanded"></a>expanded |  Whether the group is expanded by default in the UI.   | Boolean | optional |  `True`  |


<a id="nsis_installer"></a>

## nsis_installer

<pre>
load("@rules_nsis//nsis:defs.bzl", "nsis_installer")

nsis_installer(<a href="#nsis_installer-name">name</a>, <a href="#nsis_installer-arch">arch</a>, <a href="#nsis_installer-components">components</a>, <a href="#nsis_installer-compressor">compressor</a>, <a href="#nsis_installer-compressor_dictsize">compressor_dictsize</a>, <a href="#nsis_installer-copyright">copyright</a>, <a href="#nsis_installer-defines">defines</a>,
               <a href="#nsis_installer-description">description</a>, <a href="#nsis_installer-execution_level">execution_level</a>, <a href="#nsis_installer-header_image">header_image</a>, <a href="#nsis_installer-icon">icon</a>, <a href="#nsis_installer-install_categories">install_categories</a>, <a href="#nsis_installer-install_path">install_path</a>,
               <a href="#nsis_installer-install_root">install_root</a>, <a href="#nsis_installer-license_file">license_file</a>, <a href="#nsis_installer-menu_image">menu_image</a>, <a href="#nsis_installer-no_config">no_config</a>, <a href="#nsis_installer-outfile">outfile</a>, <a href="#nsis_installer-product">product</a>, <a href="#nsis_installer-product_path">product_path</a>,
               <a href="#nsis_installer-vendor">vendor</a>, <a href="#nsis_installer-vendor_path">vendor_path</a>, <a href="#nsis_installer-verbosity">verbosity</a>, <a href="#nsis_installer-version">version</a>)
</pre>

Builds a windows installer .exe using NSIS.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="nsis_installer-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="nsis_installer-arch"></a>arch |  The architecture to build the installer for.   | String | optional |  `"x86_64"`  |
| <a id="nsis_installer-components"></a>components |  The list of components and component groups to install.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="nsis_installer-compressor"></a>compressor |  Set the compressor to be used for building the installer.   | String | optional |  `"lzma"`  |
| <a id="nsis_installer-compressor_dictsize"></a>compressor_dictsize |  Set the compressor dict size for the lzma compression algorithm.   | Integer | optional |  `8`  |
| <a id="nsis_installer-copyright"></a>copyright |  The copyright of the software being packaged.   | String | optional |  `""`  |
| <a id="nsis_installer-defines"></a>defines |  A list of additional defines to include in the installer.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="nsis_installer-description"></a>description |  The description of the software being packaged.   | String | optional |  `""`  |
| <a id="nsis_installer-execution_level"></a>execution_level |  Set the execution level for the installer.   | String | optional |  `"admin"`  |
| <a id="nsis_installer-header_image"></a>header_image |  The image to use for the installer header.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="nsis_installer-icon"></a>icon |  The icon to use for the installer.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="nsis_installer-install_categories"></a>install_categories |  The possible install types to use when selecting components.   | List of strings | optional |  `["Full", "Typical", "Minimal"]`  |
| <a id="nsis_installer-install_path"></a>install_path |  Overrides install_root and vendor_path with a specific path.   | String | optional |  `""`  |
| <a id="nsis_installer-install_root"></a>install_root |  The root path to install the software into. Defaults to NSIS's built in $PROGRAMFILES64 (or $PROGRAMFILES if 32bit) when installed as admin. When installed as a user, defaults to $LOCALAPPDATA\Programs.<br><br>The final $INSTPATH for the software will be {{.InstallRoot}}\{{.VendorPath}}.   | String | optional |  `""`  |
| <a id="nsis_installer-license_file"></a>license_file |  The license file to use for the installer.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="nsis_installer-menu_image"></a>menu_image |  The image to use for the welcome and finish installer pages.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="nsis_installer-no_config"></a>no_config |  Pass /NOCONFIG to disable loading nsiconf.nsi   | Boolean | optional |  `False`  |
| <a id="nsis_installer-outfile"></a>outfile |  The outfile to create. Defaults to '{{.Vendor}} {{Product}} Setup.exe'   | String | optional |  `""`  |
| <a id="nsis_installer-product"></a>product |  The display name of the software being packaged.   | String | required |  |
| <a id="nsis_installer-product_path"></a>product_path |  The path name of the software being packaged.   | String | required |  |
| <a id="nsis_installer-vendor"></a>vendor |  The display name of the vendor providing the software.   | String | optional |  `""`  |
| <a id="nsis_installer-vendor_path"></a>vendor_path |  The optional path to use below the root by default. E.g. Company\Vendor. This will default to the provided vendor field.   | String | optional |  `""`  |
| <a id="nsis_installer-verbosity"></a>verbosity |  makensis verbosity: 0 none, 1 errors, 2 warnings, 3 info, 4 all.   | Integer | optional |  `2`  |
| <a id="nsis_installer-version"></a>version |  The numeric version for the installer.   | String | optional |  `"0.0.0.0"`  |


