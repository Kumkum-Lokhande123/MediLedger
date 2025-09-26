// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MediLedger
 * @dev A blockchain-based medical records management system
 * @author MediLedger Development Team
 */
contract MediLedger {
    
    // Struct to represent a medical record
    struct MedicalRecord {
        uint256 recordId;
        address patientAddress;
        address doctorAddress;
        string diagnosis;
        string treatment;
        string medicationsPrescribed;
        uint256 timestamp;
        bool isActive;
    }
    
    // Struct to represent a patient
    struct Patient {
        address patientAddress;
        string name;
        uint256 age;
        string bloodType;
        string allergies;
        bool isRegistered;
        uint256[] recordIds;
    }
    
    // Struct to represent a doctor
    struct Doctor {
        address doctorAddress;
        string name;
        string specialization;
        string licenseNumber;
        bool isVerified;
        uint256[] treatedPatients;
    }
    
    // State variables
    mapping(address => Patient) public patients;
    mapping(address => Doctor) public doctors;
    mapping(uint256 => MedicalRecord) public medicalRecords;
    mapping(address => mapping(address => bool)) public accessPermissions;
    
    uint256 private recordCounter;
    address public admin;
    
    // Events
    event PatientRegistered(address indexed patientAddress, string name);
    event DoctorVerified(address indexed doctorAddress, string name);
    event MedicalRecordCreated(uint256 indexed recordId, address indexed patient, address indexed doctor);
    event AccessGranted(address indexed patient, address indexed doctor);
    event AccessRevoked(address indexed patient, address indexed doctor);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyRegisteredPatient() {
        require(patients[msg.sender].isRegistered, "Patient not registered");
        _;
    }
    
    modifier onlyVerifiedDoctor() {
        require(doctors[msg.sender].isVerified, "Doctor not verified");
        _;
    }
    
    modifier hasAccess(address _patient) {
        require(
            msg.sender == _patient || 
            accessPermissions[_patient][msg.sender] || 
            msg.sender == admin,
            "Access denied"
        );
        _;
    }
    
    constructor() {
        admin = msg.sender;
        recordCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new patient
     * @param _name Patient's name
     * @param _age Patient's age
     * @param _bloodType Patient's blood type
     * @param _allergies Patient's known allergies
     */
    function registerPatient(
        string memory _name,
        uint256 _age,
        string memory _bloodType,
        string memory _allergies
    ) public {
        require(!patients[msg.sender].isRegistered, "Patient already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_age > 0, "Invalid age");
        
        patients[msg.sender] = Patient({
            patientAddress: msg.sender,
            name: _name,
            age: _age,
            bloodType: _bloodType,
            allergies: _allergies,
            isRegistered: true,
            recordIds: new uint256[](0)
        });
        
        emit PatientRegistered(msg.sender, _name);
    }
    
    /**
     * @dev Core Function 2: Add a new medical record
     * @param _patientAddress Patient's address
     * @param _diagnosis Medical diagnosis
     * @param _treatment Treatment provided
     * @param _medications Medications prescribed
     */
    function addMedicalRecord(
        address _patientAddress,
        string memory _diagnosis,
        string memory _treatment,
        string memory _medications
    ) public onlyVerifiedDoctor returns (uint256) {
        require(patients[_patientAddress].isRegistered, "Patient not registered");
        require(
            accessPermissions[_patientAddress][msg.sender] || 
            msg.sender == admin,
            "No permission to add record"
        );
        require(bytes(_diagnosis).length > 0, "Diagnosis cannot be empty");
        
        recordCounter++;
        
        medicalRecords[recordCounter] = MedicalRecord({
            recordId: recordCounter,
            patientAddress: _patientAddress,
            doctorAddress: msg.sender,
            diagnosis: _diagnosis,
            treatment: _treatment,
            medicationsPrescribed: _medications,
            timestamp: block.timestamp,
            isActive: true
        });
        
        patients[_patientAddress].recordIds.push(recordCounter);
        
        emit MedicalRecordCreated(recordCounter, _patientAddress, msg.sender);
        return recordCounter;
    }
    
    /**
     * @dev Core Function 3: Grant access to medical records
     * @param _doctorAddress Doctor's address to grant access to
     */
    function grantAccess(address _doctorAddress) public onlyRegisteredPatient {
        require(doctors[_doctorAddress].isVerified, "Doctor not verified");
        require(!accessPermissions[msg.sender][_doctorAddress], "Access already granted");
        
        accessPermissions[msg.sender][_doctorAddress] = true;
        doctors[_doctorAddress].treatedPatients.push(uint256(uint160(msg.sender)));
        
        emit AccessGranted(msg.sender, _doctorAddress);
    }
    
    // Additional utility functions
    
    /**
     * @dev Verify a doctor (only admin)
     * @param _doctorAddress Doctor's address
     * @param _name Doctor's name
     * @param _specialization Doctor's specialization
     * @param _licenseNumber Doctor's license number
     */
    function verifyDoctor(
        address _doctorAddress,
        string memory _name,
        string memory _specialization,
        string memory _licenseNumber
    ) public onlyAdmin {
        require(!doctors[_doctorAddress].isVerified, "Doctor already verified");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_licenseNumber).length > 0, "License number cannot be empty");
        
        doctors[_doctorAddress] = Doctor({
            doctorAddress: _doctorAddress,
            name: _name,
            specialization: _specialization,
            licenseNumber: _licenseNumber,
            isVerified: true,
            treatedPatients: new uint256[](0)
        });
        
        emit DoctorVerified(_doctorAddress, _name);
    }
    
    /**
     * @dev Revoke access to medical records
     * @param _doctorAddress Doctor's address to revoke access from
     */
    function revokeAccess(address _doctorAddress) public onlyRegisteredPatient {
        require(accessPermissions[msg.sender][_doctorAddress], "Access not granted");
        
        accessPermissions[msg.sender][_doctorAddress] = false;
        
        emit AccessRevoked(msg.sender, _doctorAddress);
    }
    
    /**
     * @dev Get patient's medical records
     * @param _patientAddress Patient's address
     * @return Array of record IDs
     */
    function getPatientRecords(address _patientAddress) 
        public 
        view 
        hasAccess(_patientAddress) 
        returns (uint256[] memory) 
    {
        return patients[_patientAddress].recordIds;
    }
    
    /**
     * @dev Get medical record details
     * @param _recordId Record ID
     * @return Medical record details
     */
    function getMedicalRecord(uint256 _recordId) 
        public 
        view 
        hasAccess(medicalRecords[_recordId].patientAddress)
        returns (MedicalRecord memory) 
    {
        require(medicalRecords[_recordId].isActive, "Record not found or inactive");
        return medicalRecords[_recordId];
    }
    
    /**
     * @dev Check if doctor has access to patient's records
     * @param _patientAddress Patient's address
     * @param _doctorAddress Doctor's address
     * @return Boolean indicating access status
     */
    function hasAccessToPatient(address _patientAddress, address _doctorAddress) 
        public 
        view 
        returns (bool) 
    {
        return accessPermissions[_patientAddress][_doctorAddress];
    }
    
    /**
     * @dev Get total number of records
     * @return Total record count
     */
    function getTotalRecords() public view returns (uint256) {
        return recordCounter;
    }
}
