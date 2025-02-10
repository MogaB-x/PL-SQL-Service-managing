# PL/SQL system for managing an auto repair service
The project includes comprehensive database structures with tables for clients, vehicles, procedures, and appointments, incorporating primary and foreign key constraints to ensure relational integrity. 

## Key functionalities include:
- Automated appointment scheduling: Triggers handle validation for time overlaps, enforce future-only appointments, and calculate completion times based on procedure durations.
 - Client management: Stored procedures and triggers enforce business rules, such as preventing deletion of clients with pending appointments.
- Dynamic reporting: Functions calculate service statistics, like the number of oil changes within a given period.
- Data integrity: Implemented constraints to validate email formats and ensure unique phone numbers.
