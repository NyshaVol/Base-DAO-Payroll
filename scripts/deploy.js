const hre = require("hardhat");
async function main() {
  const Payroll = await hre.ethers.getContractFactory("ZenithDaoPayroll");
  const payroll = await Payroll.deploy();
  await payroll.deployed();
  console.log("DAO Payroll deployed to:", payroll.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
