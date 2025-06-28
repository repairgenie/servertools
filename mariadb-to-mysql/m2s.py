import re
import os

def convert_mariadb_to_mysql(input_filepath, output_filepath):
    """
    Converts a SQL file exported from MariaDB to be more compatible with MySQL Community Edition.

    Specifically addresses:
    1. `DEFAULT current_timestamp()` on `VARCHAR` columns by changing them to `TIMESTAMP`
       and `DEFAULT CURRENT_TIMESTAMP`.
    2. Ensures `ENGINE=InnoDB` is used, replacing `XtraDB` if found (common MariaDB engine).
       This part is generally safe as InnoDB is the default and most common engine in MySQL.

    Args:
        input_filepath (str): The path to the original SQL file from MariaDB.
        output_filepath (str): The path where the MySQL-compatible SQL file will be saved.
    """
    try:
        with open(input_filepath, 'r', encoding='utf-8') as f:
            sql_content = f.read()

        # --- Rule 1: Fix `DEFAULT current_timestamp()` on VARCHAR columns ---
        # This regex looks for a column definition that has `varchar(...) DEFAULT current_timestamp()`
        # It's designed to be flexible enough to catch various formats of this specific issue.
        # It captures everything before and after the problematic part to reconstruct the line.
        varchar_timestamp_pattern = re.compile(
            r"(?P<pre_col_name>`\w+`\s+)"         # Matches column name like `col_name` and spaces
            r"(?:varchar\(\d+\)|longtext|mediumtext|text)\s*" # Matches varchar with length, or text types
            r"(?:COLLATE\s+\w+\s*)?"             # Optionally matches COLLATE clause
            r"(?:CHARACTER\s+SET\s+\w+\s*)?"     # Optionally matches CHARACTER SET clause
            r"(?P<nullable>NOT\s+NULL|NULL)?"    # Optionally matches NULL/NOT NULL
            r"(?P<default_problem>\s+DEFAULT\s+current_timestamp\(\))" # The problematic part
            r"(?P<post_default>.*?,?\s*(?=\n|PRIMARY KEY|KEY|UNIQUE KEY|$))", # What comes after, up to next line/key def
            re.IGNORECASE | re.DOTALL # Ignore case for keywords, DOTALL to match newlines in .*
        )

        # Replacement: change type to TIMESTAMP and default to CURRENT_TIMESTAMP
        # Also ensure NULL is explicitly set if it was previously.
        # This replacement maintains other column attributes like NOT NULL.
        def replace_varchar_timestamp(match):
            pre_col_name = match.group('pre_col_name')
            nullable = match.group('nullable') if match.group('nullable') else ''
            post_default = match.group('post_default').strip()

            # Ensure NOT NULL is explicitly carried over if it existed.
            # If NULL was specified, it will become `TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP` which is valid.
            if "NOT NULL" in nullable.upper():
                new_type_and_default = "timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP"
            else:
                # If it was nullable or had no explicit NULL/NOT NULL, make it nullable TIMESTAMP
                new_type_and_default = "timestamp DEFAULT CURRENT_TIMESTAMP"

            # Reconstruct the line
            return f"{pre_col_name}{new_type_and_default}{post_default}"

        cleaned_sql_content = varchar_timestamp_pattern.sub(replace_varchar_timestamp, sql_content)


        # --- Rule 2: Standardize ENGINE to InnoDB (from XtraDB, etc.) ---
        # MariaDB might use XtraDB which is a drop-in replacement for InnoDB,
        # but for explicit compatibility with MySQL, it's better to set InnoDB.
        # This regex targets the ENGINE clause at the end of CREATE TABLE statements.
        engine_pattern = re.compile(
            r"ENGINE=(?:XtraDB|Aria|MyISAM|Blackhole|Memory|FEDERATED|CSV|ARCHIVE|MRG_MyISAM|S3|Spider|ColumnStore|TokunDB)\b",
            re.IGNORECASE
        )
        cleaned_sql_content = engine_pattern.sub("ENGINE=InnoDB", cleaned_sql_content)

        # --- Rule 3: Remove `COLLATE latin1_swedish_ci` for database definition if present (optional) ---
        # Sometimes this causes issues if MySQL has a different default or stricter parsing for DB-level collates.
        # This is less likely to be an error based on the snippet, but can be a compatibility point.
        # If the original file contains `CREATE DATABASE ... DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci;`
        # and it's causing issues, this can be uncommented.
        # This specific pattern looks for the COLLATE clause at the end of a CREATE DATABASE statement
        # create_db_collate_pattern = re.compile(
        #     r"(DEFAULT CHARACTER SET \w+\s+COLLATE \w+)",
        #     re.IGNORECASE
        # )
        # cleaned_sql_content = create_db_collate_pattern.sub("", cleaned_sql_content)


        if sql_content == cleaned_sql_content:
            print(f"Warning: No changes were detected for common MariaDB/MySQL incompatibilities in '{input_filepath}'.")
            print("The input file might already be largely compatible, or the issues are different.")
        else:
            print(f"Changes applied to '{input_filepath}'.")

        with open(output_filepath, 'w', encoding='utf-8') as f:
            f.write(cleaned_sql_content)

        print(f"Successfully converted '{input_filepath}' and saved to '{output_filepath}'")
        print("You can now try importing the new file into MySQL Community Edition.")

    except FileNotFoundError:
        print(f"Error: Input file '{input_filepath}' not found.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

# --- How to use the script ---
if __name__ == "__main__":
    # Define your input and output file paths
    # Ensure 'cloudcent_admin.sql' is in the same directory as this script,
    # or provide the full path to it.
    input_sql_file = "cloudcent_admin.sql"
    output_sql_file = "cloudcent_admin_mysql_compatible.sql"

    convert_mariadb_to_mysql(input_sql_file, output_sql_file)
