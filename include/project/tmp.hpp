#ifndef PROJECT_TMP_HPP_
#define PROJECT_TMP_HPP_

#include <iostream>

#include <project/export.hpp>

namespace tmp {

PROJECT_EXPORT int add(int left, int right);

PROJECT_EXPORT void DumpBuildInfo(std::ostream& ostream = std::cout);

}  // namespace tmp

#endif  // PROJECT_TMP_HPP_
