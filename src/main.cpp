#include <iostream>

#include "tmp.hpp"
#include "version.hpp"

int main(int argc, char* argv[])
{
  std::cout << "Hello, World!" << std::endl;

  std::cout << tmp::add(1, 2) << std::endl;

  for (int i = 0; i < argc; ++i)
  {
    std::cout << argv[i] << std::endl;
  }

  return 0;
}
