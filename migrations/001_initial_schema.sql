-- ============================================================
-- Migration 001: Initial Schema
-- Description: Creates all base tables for DRRMS
-- ============================================================

-- UP Migration
-- This serves as documentation of the initial schema
-- Run 01_schema.sql for the actual table creation

-- Record this migration
INSERT INTO _migrations (version, name, status) 
VALUES ('001', 'initial_schema', 'applied')
ON DUPLICATE KEY UPDATE status = 'applied';

-- DOWN Migration (Rollback)
-- WARNING: This will destroy all data!
/*
DROP TABLE IF EXISTS Donation;
DROP TABLE IF EXISTS Donor;
DROP TABLE IF EXISTS Allocation;
DROP TABLE IF EXISTS Request;
DROP TABLE IF EXISTS Volunteer;
DROP TABLE IF EXISTS Relief_Team;
DROP TABLE IF EXISTS Inventory;
DROP TABLE IF EXISTS Resource;
DROP TABLE IF EXISTS Affected_Area;
DROP TABLE IF EXISTS Disaster;

DELETE FROM _migrations WHERE version = '001';
*/
