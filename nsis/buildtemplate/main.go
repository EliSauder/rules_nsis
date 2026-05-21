package main

type Component struct {
	Name                string
	Directory           string
	Service             bool
	ServiceExecutable   string
	ServiceArgs         string
	ServiceStartType    []string
	ServiceDependencies []string
	SelectionMode       string
	DisplayName         string
	Description         string
	InstallCategories   []string
	Files               []string
	Directories         []string
	Dependencies        []string
}

type ComponentGroup struct {
	Name            string
	Description     string
	Expanded        bool
	Bold            bool
	DisplayName     string
	Components      []Component
	ComponentGroups []ComponentGroup
}

type Installer struct {
	Name         string
	Product      string
	Company      string
	Description  string
	Copyright    string
	LicenseFile  string
	Version      string
	Architecture string

	InstallRoot        string
	InstallPath        string
	ExecutionLevel     string
	Compressor         string
	CompressorDictSize string
	Icon               string
	HeaderImage        string
	MenuImage          string

	Components      []Component
	ComponentGroups []ComponentGroup
}

func main() {
}
