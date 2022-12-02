# Project iman

A 99% pure Bash utility that presents an indexed access to **man**
pages.

Given a request for a **man** page, the utility builds the index
from the section heads and subheads found in the **groff** code
of the **man** page file.  It accesses each index item by specifying
a search via pass-through arguments to the **less** pager utility.

## USAGE

Assuming setup as recommended below, usage is simple: simply type
**iman** followed by the desired manpage.  You can specify the
section as an argument, an extension, or in parentheses:

**iman** *3 printf*  
**iman** *printf.3*  
**iman** *printf\\(3\\)*  
**iman** *'printf(3)'*

There are no other options for now.

If the page is found, **iman** will display a list of *Section Heads_.
Open a section by selecting the selection with the arrow keys and
pressing `ENTER`.  Alternately, the user can type the highlighted
letter of the desired section.  The section opens immediately if the
highlighted letter is unique for the page, or it will cycle through
sections with the same highlighted letter, after which the user
presses `ENTER` to open the highlighted section.

## SETUP

Installation is a two-step process because this project depends on
another of my projects.

### Assumptions

To avoid including **sudo** installation commands, the following
instructions assume the following:

- The installation system includes a **~/.local** directory with
  **~/.local/bin** and **~/.local/opt** subdirectories.

- The installation system path includes a reference to
  **~/.local/bin** which will make an executable file there
  accessible without specifying the path.

- People reading this page will know how to adjust these
  assumptions to suit their needs.

### Step 1: Download *iman* and supporting project

~~~sh
user@host:~$ cd .local/opt
user@host:~/.local/opt$ git clone www.github.com/cjungmann/iman.git
user@host:~/.local/opt$ git clone www.github.com/cjungmann/bash_patterns.git
~~~

### Step 2: Create resource link
~~~sh
user@host:~/.local/opt$ cd iman
user@host:~/.local/opt/iman$ ln -s ../bash_patterns/sources sources
~~~

### Step 3: Create executable link
~~~sh
user@host:~/.local/opt/iman$ cd ~/.local/bin
user@host:~/.local/bin$ cp -s ../opt/iman/iman .
~~~

## BASH_PATTERNS

This project builds on another project of mine that enables a text
user interface entirely built in Bash.

The project is [bash_patterns](httsp://www.github.com/cjungmann/bash_patterns).
This project uses the **sources** directory of **bash_patterns**.

I thought about trying to make **iman** self-sufficient, but the
scope of **bash_patterns** is bigger than I wanted to duplicate.

## ARTIFACTS

This project started as a survey project, and the tools still
exists to rerun a survey, despite refactoring breaking the
original survey.  **ms_read** is broken, but kept for posterity.

While playing with the code and the results, I remembered a more
useful idea I had about indexing long **man** mages.  That prompted
a name change to **iman** for indexed man.

