-- ============================================================
-- DISASTER RELIEF RESOURCE MANAGEMENT SYSTEM (DRRMS)
-- Triggers - Automated Database Operations
-- ============================================================

USE drrms_db;

-- ============================================================
-- TRIGGER 1: Auto-update inventory after allocation
-- When allocation is created, reduce inventory quantity
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_after_allocation_insert
AFTER INSERT ON Allocation
FOR EACH ROW
BEGIN
    -- Reduce the quantity from inventory
    UPDATE Inventory 
    SET quantity_available = quantity_available - NEW.quantity_allocated,
        last_updated = CURRENT_TIMESTAMP
    WHERE inventory_id = NEW.inventory_id;
    
    -- Update request status to 'Approved' if it was 'Pending'
    UPDATE Request 
    SET status = 'Approved'
    WHERE request_id = NEW.request_id AND status = 'Pending';
END //

DELIMITER ;

-- ============================================================
-- TRIGGER 2: Restore inventory if allocation is cancelled
-- When allocation is deleted, restore inventory quantity
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_after_allocation_delete
AFTER DELETE ON Allocation
FOR EACH ROW
BEGIN
    -- Restore the quantity to inventory
    UPDATE Inventory 
    SET quantity_available = quantity_available + OLD.quantity_allocated,
        last_updated = CURRENT_TIMESTAMP
    WHERE inventory_id = OLD.inventory_id;
END //

DELIMITER ;

-- ============================================================
-- TRIGGER 3: Update request status when allocation is delivered
-- When delivery_status changes to 'Delivered', update request
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_after_allocation_update
AFTER UPDATE ON Allocation
FOR EACH ROW
BEGIN
    DECLARE total_requested INT;
    DECLARE total_delivered INT;
    
    -- Check if delivery status changed to 'Delivered'
    IF NEW.delivery_status = 'Delivered' AND OLD.delivery_status != 'Delivered' THEN
        
        -- Get total requested and delivered for this request
        SELECT r.quantity_requested INTO total_requested
        FROM Request r
        WHERE r.request_id = NEW.request_id;
        
        SELECT COALESCE(SUM(a.quantity_allocated), 0) INTO total_delivered
        FROM Allocation a
        WHERE a.request_id = NEW.request_id AND a.delivery_status = 'Delivered';
        
        -- Update request status based on fulfillment
        IF total_delivered >= total_requested THEN
            UPDATE Request SET status = 'Fulfilled' WHERE request_id = NEW.request_id;
        ELSE
            UPDATE Request SET status = 'Partially_Fulfilled' WHERE request_id = NEW.request_id;
        END IF;
        
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRIGGER 4: Set volunteer availability when assigned to team
-- When volunteer is assigned to a team, set availability to 'Busy'
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_after_volunteer_update
AFTER UPDATE ON Volunteer
FOR EACH ROW
BEGIN
    -- If team assignment changed
    IF NEW.team_id IS NOT NULL AND (OLD.team_id IS NULL OR OLD.team_id != NEW.team_id) THEN
        -- Volunteer was assigned to a team, already handled by the update
        -- This trigger can be extended for logging or notifications
        SELECT 1; -- Placeholder
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRIGGER 5: Auto-generate receipt number for donations
-- When donation is inserted without receipt_no, generate one
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_before_donation_insert
BEFORE INSERT ON Donation
FOR EACH ROW
BEGIN
    DECLARE year_str VARCHAR(4);
    DECLARE next_seq INT;
    
    -- Generate receipt number if not provided
    IF NEW.receipt_no IS NULL OR NEW.receipt_no = '' THEN
        SET year_str = YEAR(CURRENT_DATE);
        
        -- Get next sequence number for this year
        SELECT COALESCE(MAX(
            CAST(SUBSTRING_INDEX(receipt_no, '-', -1) AS UNSIGNED)
        ), 0) + 1 INTO next_seq
        FROM Donation
        WHERE receipt_no LIKE CONCAT('DON-', year_str, '-%');
        
        -- Set the receipt number
        SET NEW.receipt_no = CONCAT('DON-', year_str, '-', LPAD(next_seq, 3, '0'));
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRIGGER 6: Validate allocation quantity
-- Ensure allocation doesn't exceed available inventory
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_before_allocation_insert
BEFORE INSERT ON Allocation
FOR EACH ROW
BEGIN
    DECLARE available_qty INT;
    
    -- Get available quantity from inventory
    SELECT quantity_available INTO available_qty
    FROM Inventory
    WHERE inventory_id = NEW.inventory_id;
    
    -- Check if allocation quantity exceeds available
    IF NEW.quantity_allocated > available_qty THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Allocation quantity exceeds available inventory';
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRIGGER 7: Update disaster status when all areas resolved
-- (Optional: Can be called manually or via scheduled event)
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_after_area_update
AFTER UPDATE ON Affected_Area
FOR EACH ROW
BEGIN
    -- This trigger can be extended to auto-update disaster status
    -- when all requests in all areas are fulfilled
    SELECT 1; -- Placeholder for future enhancement
END //

DELIMITER ;

-- ============================================================
-- TRIGGER 8: Log donation receipt for material donations
-- Add to inventory when material donation is received
-- ============================================================
DELIMITER //

CREATE TRIGGER trg_after_donation_insert
AFTER INSERT ON Donation
FOR EACH ROW
BEGIN
    DECLARE default_warehouse VARCHAR(100);
    DECLARE existing_inventory_id INT;
    
    -- Only process material donations
    IF NEW.donation_type = 'Material' AND NEW.resource_id IS NOT NULL AND NEW.quantity IS NOT NULL THEN
        
        -- Default warehouse for donations
        SET default_warehouse = 'Central Warehouse, Kolkata';
        
        -- Check if inventory record exists for this resource and warehouse
        SELECT inventory_id INTO existing_inventory_id
        FROM Inventory
        WHERE resource_id = NEW.resource_id AND warehouse_location = default_warehouse
        LIMIT 1;
        
        IF existing_inventory_id IS NOT NULL THEN
            -- Update existing inventory
            UPDATE Inventory 
            SET quantity_available = quantity_available + NEW.quantity,
                last_updated = CURRENT_TIMESTAMP
            WHERE inventory_id = existing_inventory_id;
        ELSE
            -- Create new inventory record
            INSERT INTO Inventory (resource_id, warehouse_location, quantity_available)
            VALUES (NEW.resource_id, default_warehouse, NEW.quantity);
        END IF;
        
    END IF;
END //

DELIMITER ;

-- ============================================================
-- TRIGGERS CREATED: 8
-- ============================================================
-- 1. trg_after_allocation_insert   - Reduce inventory on allocation
-- 2. trg_after_allocation_delete   - Restore inventory on cancellation
-- 3. trg_after_allocation_update   - Update request status on delivery
-- 4. trg_after_volunteer_update    - Handle volunteer assignment
-- 5. trg_before_donation_insert    - Auto-generate receipt number
-- 6. trg_before_allocation_insert  - Validate allocation quantity
-- 7. trg_after_area_update         - Placeholder for area updates
-- 8. trg_after_donation_insert     - Add material donations to inventory
-- ============================================================

-- To view triggers:
-- SHOW TRIGGERS;

-- To drop a trigger:
-- DROP TRIGGER IF EXISTS trigger_name;
