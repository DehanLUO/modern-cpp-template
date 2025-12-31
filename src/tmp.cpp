#include <iostream>

#include <project/tmp.hpp>
#include <project/version.hpp>

#include "buildinfo_lib.hpp"

namespace tmp {

int add(int left, int right) { return left + right; }

void DumpBuildInfo(std::ostream& ostream) {
  ostream << "Build Information\n";
  ostream << "-----------------\n";
  ostream << "Version  : " << project::version << "\n";
  ostream << "Build    : " << project::build_type << " (" << project::build_timestamp << ")\n";
  ostream << "User     : " << project::build_user << " @ " << project::build_host << "\n\n";

  ostream << "Platform : " << project::target_system << " " << project::target_architecture << "\n";
  ostream << "Host     : " << project::host_system << "\n\n";

  ostream << "Compiler : " << project::compiler_id << " " << project::compiler_version << "\n\n";

  ostream << "Source   : " << project::git_describe << '\n';
  ostream << "Commit   : " << project::git_commit_hash << '\n';
}

}  // namespace tmp