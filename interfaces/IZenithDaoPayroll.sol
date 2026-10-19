// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;
interface IZenithDaoPayroll {
    function withdrawSalary(uint256 employeeId) external;
    function depositPayrollFunds() external payable;
}
