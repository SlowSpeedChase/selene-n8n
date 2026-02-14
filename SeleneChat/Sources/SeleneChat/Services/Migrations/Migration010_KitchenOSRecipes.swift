import Foundation
import SQLite

struct Migration010_KitchenOSRecipes {
    static func run(db: Connection) throws {
        // Recipes table (indexed from KitchenOS Obsidian vault)
        try db.run("""
            CREATE TABLE IF NOT EXISTS recipes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                content_hash TEXT UNIQUE NOT NULL,
                source_url TEXT,
                source_channel TEXT,
                file_path TEXT NOT NULL,
                servings INTEGER,
                prep_time_minutes INTEGER,
                cook_time_minutes INTEGER,
                difficulty TEXT CHECK(difficulty IN ('easy', 'medium', 'hard')),
                cuisine TEXT,
                protein TEXT,
                dish_type TEXT,
                meal_occasions TEXT,
                dietary TEXT,
                ingredients TEXT NOT NULL,
                calories INTEGER,
                nutrition_protein INTEGER,
                carbs INTEGER,
                fat INTEGER,
                indexed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT,
                status TEXT DEFAULT 'active' CHECK(status IN ('active', 'archived')),
                test_run TEXT DEFAULT NULL
            )
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_recipes_content_hash ON recipes(content_hash)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_recipes_status ON recipes(status)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_recipes_cuisine ON recipes(cuisine)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_recipes_protein ON recipes(protein)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_recipes_test_run ON recipes(test_run)")

        // Meal plans table
        try db.run("""
            CREATE TABLE IF NOT EXISTS meal_plans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                week TEXT NOT NULL UNIQUE,
                status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'active', 'completed')),
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT,
                exported_at TEXT,
                test_run TEXT DEFAULT NULL
            )
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_meal_plans_week ON meal_plans(week)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_meal_plans_status ON meal_plans(status)")

        // Meal plan items table
        try db.run("""
            CREATE TABLE IF NOT EXISTS meal_plan_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                meal_plan_id INTEGER NOT NULL,
                day TEXT NOT NULL CHECK(day IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')),
                meal TEXT NOT NULL CHECK(meal IN ('breakfast', 'lunch', 'dinner')),
                recipe_id INTEGER,
                recipe_title TEXT NOT NULL,
                notes TEXT,
                FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE,
                FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE SET NULL,
                UNIQUE(meal_plan_id, day, meal)
            )
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_meal_plan_items_plan ON meal_plan_items(meal_plan_id)")

        // Shopping items table
        try db.run("""
            CREATE TABLE IF NOT EXISTS shopping_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                meal_plan_id INTEGER NOT NULL,
                ingredient TEXT NOT NULL,
                amount REAL,
                unit TEXT,
                category TEXT CHECK(category IN ('produce', 'dairy', 'meat', 'pantry', 'frozen', 'bakery', 'other')),
                checked INTEGER DEFAULT 0,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id) ON DELETE CASCADE
            )
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_shopping_items_plan ON shopping_items(meal_plan_id)")

        print("Migration 010: KitchenOS recipe, meal plan, and shopping tables created")
    }
}
