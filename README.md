# 🚗 PL/SQL Auto Repair Service Management System
- This project includes PL/SQL-based system with tables for clients, vehicles, procedures, and appointments, incorporating primary and foreign key constraints to ensure relational integrity.

## 🛠️ Features
### 📅 Appointment Scheduling
- Triggers handle validation for time overlaps, enforce future-only appointments, and calculate completion times based on procedure durations.

### 👥 Client & Vehicle Management
-  Stored procedures and triggers enforce business rules, such as preventing deletion of clients with pending appointments.
  
### 📊 Dynamic Reporting & Statistics
- Functions generate service statistics, like the number of oil changes within a given period.

### ✅ Data Integrity & Validation
- Constraints ensure valid email formats and unique phone numbers.
