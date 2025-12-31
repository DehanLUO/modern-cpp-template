#include <iostream>
#include <project/tmp.hpp>

#include "buildinfo_bin.hpp"

namespace {

void DumpBuildInfo(std::ostream& ostream = std::cout) {
  ostream << "Build Information\n";
  ostream << "-----------------\n";
  ostream << "Build    : " << project::build_type << " (" << project::build_timestamp << ")\n";
  ostream << "User     : " << project::build_user << " @ " << project::build_host << "\n\n";

  ostream << "Platform : " << project::target_system << " " << project::target_architecture << "\n";
  ostream << "Host     : " << project::host_system << "\n\n";

  ostream << "Compiler : " << project::compiler_id << " " << project::compiler_version << "\n\n";

  ostream << "Source   : " << project::git_describe << '\n';
  ostream << "Commit   : " << project::git_commit_hash << '\n';
}

}  // namespace

int main(int /*argc*/, char** /*argv*/) {
  tmp::DumpBuildInfo();

  DumpBuildInfo();

  return 0;
}
