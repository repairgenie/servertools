# MariaDB to MySQL SQL Converter (m2s.py) Documentation

## Overview

The `m2s.py` script is a Python utility designed to convert a SQL database dump file exported from MariaDB into a format that is more compatible with MySQL Community Edition. It addresses specific, common syntax and feature differences between the two database systems that can cause errors when importing a MariaDB SQL file into MySQL.

The script reads an input SQL file, applies a series of predefined corrections using regular expressions, and writes the modified content to a new output file.

## The Problems It Solves

This script is targeted at fixing two primary incompatibilities:

1.  **Invalid Default Values on Text/Varchar Columns**: MariaDB allows setting `DEFAULT current_timestamp()` on columns with `VARCHAR` and `TEXT` data types. MySQL does not permit this and will throw an error. The script automatically detects such columns and converts them to the appropriate `TIMESTAMP` data type with a valid `DEFAULT CURRENT_TIMESTAMP` expression.

2.  **Storage Engine Incompatibility**: MariaDB often uses storage engines like `XtraDB` or `Aria` by default. While `XtraDB` is a drop-in replacement for `InnoDB`, an explicit `ENGINE=XtraDB` clause in the SQL file can cause issues if the target MySQL server doesn't recognize the name. The script standardizes these by replacing them with `ENGINE=InnoDB`, which is the standard, fully compatible engine in MySQL.

## How to Use

1.  **Save the Script**: Save the provided code as a file named `m2s.py`.

2.  **Place Your SQL File**: Put the SQL file exported from MariaDB (e.g., `cloudcent_admin.sql`) in the same directory as the `m2s.py` script. If your file is located elsewhere, you will need to provide the full path in the next step.

3.  **Configure File Paths**: Open `m2s.py` in a text editor. At the bottom of the file, inside the `if __name__ == "__main__":` block, you can modify the `input_sql_file` and `output_sql_file` variables to match your filenames.

    -   `input_sql_file`: The name of your original MariaDB SQL file.
    -   `output_sql_file`: The name for the new, MySQL-compatible file that the script will create.

4.  **Run the Script**: Open a terminal or command prompt, navigate to the directory where you saved the files, and execute the script using Python:

        python m2s.py

5.  **Import the New File**: Once the script finishes, a new file (e.g., `cloudcent_admin_mysql_compatible.sql`) will be created in the same directory. You can now use this new file to import your database into MySQL Community Edition.

## Console Output

When you run the script, it will print messages to the console indicating its progress:

-   If changes were made, it will output a success message:

        Changes applied to 'cloudcent_admin.sql'.
        Successfully converted 'cloudcent_admin.sql' and saved to 'cloudcent_admin_mysql_compatible.sql'
        You can now try importing the new file into MySQL Community Edition.

-   If the script runs but does not find any of the specific incompatibilities it targets, it will print a warning:

        Warning: No changes were detected for common MariaDB/MySQL incompatibilities in 'cloudcent_admin.sql'.
        The input file might already be largely compatible, or the issues are different.

-   If the input file cannot be found, it will print a `FileNotFoundError`.

## Limitations

This script is designed to fix only the specific issues mentioned above. It is not a comprehensive SQL converter and may not fix all possible syntax differences between MariaDB and MySQL. If you still encounter errors after running the script, further manual inspection of the SQL file may be necessary.