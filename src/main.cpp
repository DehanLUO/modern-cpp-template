#include <iostream>
#include <project/tmp.hpp>

#include "buildinfo_bin.hpp"

void DumpBuildInfo(std::ostream& ostream = std::cout) {
  ostream << "Build Information\n"
             "-----------------\n"
             "Build    : "
          << BUILD_TYPE << " (" << BUILD_TIMESTAMP
          << ")\n"
             "User     : "
          << BUILD_USER << " @ " << BUILD_HOST
          << "\n\n"

             "Platform : "
          << TARGET_SYSTEM << " " << TARGET_ARCHITECTURE
          << "\n"
             "Host     : "
          << HOST_SYSTEM
          << "\n\n"

             "Compiler : "
          << COMPILER_ID << " " << COMPILER_VERSION
          << "\n\n"

             "Source   : "
          << GIT_DESCRIBE << '\n'
          << "Commit   : " << GIT_COMMIT_HASH << '\n';
}

int main(int argc, char* argv[]) {
  tmp::DumpBuildInfo();

  DumpBuildInfo();

  return 0;
}

//
