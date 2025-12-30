#include <iostream>
#include <project/tmp.hpp>
#include <project/version.hpp>

#include "buildinfo_lib.hpp"

int tmp::add(int a, int b) { return a + b; }

void tmp::DumpBuildInfo(std::ostream& os) {
  os << "Build Information\n"
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