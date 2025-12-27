#include "tmp.hpp"

#include <gtest/gtest.h>

TEST(TmpAddTest, CheckValues)
{
  // ASSERT_EQ(tmp::add(1, 2), 3);
  ASSERT_EQ(tmp::show(6), 6);
  EXPECT_TRUE(true);
}

int main(int argc, char** argv)
{
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
