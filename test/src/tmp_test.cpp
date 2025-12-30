#include <sstream>
#include <string>

#include <gtest/gtest.h>

#include <project/tmp.hpp>

TEST(TmpAddTest, CheckValues) {
  ASSERT_EQ(tmp::add(1, 2), 3);
  EXPECT_TRUE(true);
}

TEST(BuildInfoTest, DumpBuildInfo_OutputContainsExpectedFields) {
  std::ostringstream oss;
  tmp::DumpBuildInfo(oss);
  std::string output = oss.str();

  EXPECT_FALSE(output.empty());
}

int main(int argc, char** argv) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
