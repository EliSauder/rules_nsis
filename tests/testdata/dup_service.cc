// A real compiled binary for the signing tests.
//
// Signing routes inputs to a signer by extension, and only the PE signer
// (osslsigncode) refuses to write an output path that already exists. A
// component that lists one executable in both `srcs` and `service_executable`
// therefore only reproduces the duplicate-signing bug with a genuine PE file,
// which is why this is compiled rather than checked in as a stub.
int main() {
  return 0;
}
