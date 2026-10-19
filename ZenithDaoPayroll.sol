// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

contract ZenithDaoPayroll {
    struct Employee {
        address payable wallet;
        uint256 salaryPerSecondWei;
        uint256 lastWithdrawalTimestamp;
        bool isActive;
    }

    address payable public immutable payrollAdmin;
    string public systemDescriptor;
    uint256 public platformFeeBps; // 200 = 2%
    uint256 public employeeCounter;
    uint256 public accumulatedFees;
    bool public isSystemHalted;

    mapping(uint256 => Employee) public employees;

    event EmployeeAdded(uint256 indexed employeeId, address indexed wallet, uint256 salaryPerSec);
    event EmployeeCanceled(uint256 indexed employeeId);
    event FundsDeposited(address indexed funder, uint256 netAmount, uint256 feeAmount);
    event TreasuryEmptied(address indexed admin, uint256 amount);
    event FeesGathered(address indexed admin, uint256 amount);
    event SystemHaltToggled(bool isHalted);
    event SalaryModified(uint256 indexed employeeId, uint256 newSalaryPerSec);
    event DescriptorUpdated(string newDescriptor);
    event SalaryWithdrawn(uint256 indexed employeeId, address indexed wallet, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == payrollAdmin, "ZenithPayroll: Access denied");
        _;
    }

    modifier whenNotHalted() {
        require(!isSystemHalted, "ZenithPayroll: System is halted");
        _;
    }

    constructor() {
        payrollAdmin = payable(msg.sender);
        systemDescriptor = "Zenith Base DAO Payroll v1";
        platformFeeBps = 200; // 2%
        isSystemHalted = false;
    }

    // 1. addEmployee
    function addEmployee(address payable wallet, uint256 salaryPerSecondWei) external onlyAdmin returns (uint256) {
        require(wallet != address(0), "ZenithPayroll: Zero address");
        require(salaryPerSecondWei > 0, "ZenithPayroll: Zero salary");

        employeeCounter++;
        employees[employeeCounter] = Employee({
            wallet: wallet,
            salaryPerSecondWei: salaryPerSecondWei,
            lastWithdrawalTimestamp: block.timestamp,
            isActive: true
        });

        emit EmployeeAdded(employeeCounter, wallet, salaryPerSecondWei);
        return employeeCounter;
    }

    // 2. cancelEmployee
    function cancelEmployee(uint256 employeeId) external onlyAdmin {
        Employee storage e = employees[employeeId];
        require(employeeId > 0 && employeeId <= employeeCounter, "ZenithPayroll: Invalid ID");
        require(e.isActive, "ZenithPayroll: Already inactive");

        e.isActive = false;
        emit EmployeeCanceled(employeeId);
    }

    // 3. depositPayrollFunds
    function depositPayrollFunds() external payable whenNotHalted {
        require(msg.value > 0, "ZenithPayroll: Zero deposit");
        
        uint256 fee = (msg.value * platformFeeBps) / 10000;
        uint256 netDeposit = msg.value - fee;
        
        accumulatedFees += fee;
        
        emit FundsDeposited(msg.sender, netDeposit, fee);
    }

    // 4. emptyTreasury
    function emptyTreasury() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "ZenithPayroll: Zero balance");

        accumulatedFees = 0;
        (bool sent, ) = payrollAdmin.call{value: balance}("");
        require(sent, "ZenithPayroll: Sweep failed");

        emit TreasuryEmptied(payrollAdmin, balance);
    }

    // 5. gatherPlatformFees
    function gatherPlatformFees() external onlyAdmin {
        uint256 amount = accumulatedFees;
        require(amount > 0, "ZenithPayroll: Zero fees");

        accumulatedFees = 0;
        (bool sent, ) = payrollAdmin.call{value: amount}("");
        require(sent, "ZenithPayroll: Harvest failed");

        emit FeesGathered(payrollAdmin, amount);
    }

    // 6. haltPayrollSystem
    function haltPayrollSystem(bool isHalted) external onlyAdmin {
        isSystemHalted = isHalted;
        emit SystemHaltToggled(isHalted);
    }

    // 7. modifyEmployeeSalary
    function modifyEmployeeSalary(uint256 employeeId, uint256 newSalaryPerSecondWei) external onlyAdmin {
        Employee storage e = employees[employeeId];
        require(employeeId > 0 && employeeId <= employeeCounter, "ZenithPayroll: Invalid ID");
        require(e.isActive, "ZenithPayroll: Inactive employee");
        require(newSalaryPerSecondWei > 0, "ZenithPayroll: Zero salary");

        e.salaryPerSecondWei = newSalaryPerSecondWei;
        emit SalaryModified(employeeId, newSalaryPerSecondWei);
    }

    // 8. updateSystemDescriptor
    function updateSystemDescriptor(string calldata newDescriptor) external onlyAdmin {
        require(bytes(newDescriptor).length > 0, "ZenithPayroll: Empty string");
        systemDescriptor = newDescriptor;
        emit DescriptorUpdated(newDescriptor);
    }

    // 9. withdrawSalary
    function withdrawSalary(uint256 employeeId) external {
        Employee storage e = employees[employeeId];
        require(employeeId > 0 && employeeId <= employeeCounter, "ZenithPayroll: Invalid ID");
        require(msg.sender == e.wallet, "ZenithPayroll: Unauthorized wallet");
        require(e.isActive, "ZenithPayroll: Inactive employee");

        uint256 timePassed = block.timestamp - e.lastWithdrawalTimestamp;
        require(timePassed > 0, "ZenithPayroll: No time passed");

        uint256 payout = timePassed * e.salaryPerSecondWei;
        require(address(this).balance - accumulatedFees >= payout, "ZenithPayroll: Insufficient treasury");

        e.lastWithdrawalTimestamp = block.timestamp;

        (bool sent, ) = e.wallet.call{value: payout}("");
        require(sent, "ZenithPayroll: Transfer failed");

        emit SalaryWithdrawn(employeeId, e.wallet, payout);
    }
}