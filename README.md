# Project iman

A 99% pure Bash utility that presents an indexed access to **man**
pages.

Given a request for a **man** page, the utility builds the index
from the section heads and subheads found in the **groff** code
of the **man** page file.  It accesses each index item by specifying
a search via pass-through arguments to the **less** pager utility.

## USAGE

This is simple, type **iman** where you might type **man**.  It's
not perfectly compatible: it won't properly handle a list of **man**
pages like **man** does.

~~~sh
iman bash
~~~

will show you an index of _Section Heads_.  Click on a section head
and the script will open the **man** page with that section head at
the top of the screen.

Not yet working is the option to view the _Subheads_ under a section
head.  I have a couple of ideas on how to do this, so it's still a
work in progress.  It seems necessary for very long documents like
the **Bash** man page.

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

The project is [bash_patterns](httsp://www.github.com/cjungmann/bash_patterns].
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

