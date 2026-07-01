# Student Setup Guide — CAJAL Neuromics 2026

## Prerequisites

- Your IFB username (format: `tp18XXXX`)

---

## Step 1 — Install VSCode

Download and install VSCode for your OS: https://code.visualstudio.com/download

---

## Step 2 — Install the required extensions

Open VSCode → Extensions view (`Ctrl+Shift+X` / `Cmd+Shift+X` on Mac) → search for each and click **Install**:

| Extension | Publisher | Why you need it |
|---|---|---|
| **Remote - SSH** | Microsoft | Connect VSCode to the IFB cluster over SSH |
| **R** | REditorSupport | Run `.qmd` notebook cells directly against the remote R session |
| **Quarto** | Quarto | Preview and render `.qmd` notebooks |
| **Python** | Microsoft | Interpreter/kernel support for the Jupyter extension |
| **Jupyter** | Microsoft | Run `.ipynb` notebook cells against the remote Python kernel |

Or, if you have the `code` CLI on your PATH, install all five from a terminal:

```bash
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension REditorSupport.r
code --install-extension quarto.quarto
code --install-extension ms-python.python
code --install-extension ms-toolsai.jupyter
```

---

## Step 3 — Generate an SSH key and add it to the cluster

This lets you connect without typing your password every time.

On your laptop:
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```
Press Enter to accept the default location (`~/.ssh/id_ed25519`). Set a passphrase or leave it empty.

Copy the public key to the cluster:
```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub tp18XXXX@core-login2.cluster.france-bioinformatique.fr
```
(You'll be asked for your password one last time.)

If your system doesn't have `ssh-copy-id` (e.g. some Windows setups), do it manually instead:
```bash
cat ~/.ssh/id_ed25519.pub | ssh tp18XXXX@core-login2.cluster.france-bioinformatique.fr "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

---

## Step 4 — Connect to the cluster

Add this to your SSH config file:
- Mac/Linux: `~/.ssh/config`
- Windows: `C:\Users\<YourName>\.ssh\config`

```
Host ifb-neuromics
  HostName core-login2.cluster.france-bioinformatique.fr
  User tp18XXXX
  IdentityFile ~/.ssh/id_ed25519
```

In VSCode: open the Command Palette (`Ctrl+Shift+P`) → **Remote-SSH: Connect to Host** → select `ifb-neuromics`.

---

## Step 5 — Request a compute node

**Option A — srun** (single command):
```bash
srun --partition=fast --cpus-per-task=8 --mem=128G --time=08:00:00 --pty bash
```
Wait for the prompt to change — you are now on a compute node.

**Option B — salloc + ssh** (two steps, keeps a login node terminal free):
```bash
salloc --partition=fast --cpus-per-task=8 --mem=128G --time=08:00:00
```
Note the node name printed (e.g. `cpu-node-24`), then in the **same terminal**:
```bash
ssh cpu-node-24
```

You'll use this same compute node for both the R/Quarto notebooks (Steps 6–11) and the Python/Jupyter notebook (Steps 12–13).

---

## Step 6 — Launch the container (R / Quarto notebooks)

Replace `C10` below with your group number (C9–C16):

```bash
PROJ=/shared/projects/tp_2630_ubordeaux_neuromics_184418/projects/C10
SIF=/shared/projects/tp_2630_ubordeaux_neuromics_184418/containers/alan/cajal.sif

apptainer exec \
  --bind $PROJ:$PROJ \
  $SIF bash -i
```

Note the value of `PROJ` — you will paste it into the notebook setup in the next step.

---

## Step 7 — Start R

Inside the container, type:

```bash
R
```

---

## Step 8 — Create your figures folder

Run this once from inside the container (use the same path as `PROJ`):

```bash
mkdir -p $PROJ/figures
```

---

## Step 9 — Run the R/Quarto notebooks

Open any `.qmd` file from your git checkout's `notebooks/` folder in VSCode and click **Run Cell**.

In the **first setup cell**, set `PROJ_DIR` to your shared project path (for data) and `GIT_DIR` to your git checkout path (for code):

```r
PROJ_DIR <- "/shared/projects/tp_2630_ubordeaux_neuromics_184418/projects/C10"
GIT_DIR  <- "~/cajal-project-alan"
```

VSCode sends each cell directly to the R session running in your terminal — inside the container, on your 128 GB compute node.

To render the full notebook to HTML:

```bash
quarto render notebook1.qmd
```

---

## Step 10 — View plots interactively (httpgd)

When the notebook setup chunk runs, httpgd starts and prints a URL like:
```
httpgd server running at:
  http://127.0.0.1:45033/live?token=VApJKIg6
```

Note the **port** (e.g. `45033`) and your **compute node name** (visible in your terminal prompt, e.g. `cpu-node-24`).

Open a **second terminal** in VSCode (click `+` in the terminal panel) — it will open on the login node. Run:
```bash
ssh -fN -L 45033:localhost:45033 cpu-node-24
```
Replace `45033` with your port and `cpu-node-24` with your node.

Then open the viewer:
1. Go to the **PORTS** tab (bottom panel, next to TERMINAL)
2. Find the port → right-click → **Open Preview**
3. In the address bar paste the full URL including the token:
   `http://127.0.0.1:45033/live?token=VApJKIg6`
4. Press Enter — plots will now appear here as you run them

When done for the day, kill the tunnel:
```bash
pkill -f "ssh -fN -L"
```

---

## Step 11 — Save plots to file

For plots you want to keep:

```r
p <- DimPlot(sci, group.by = "cell_type", ...)
ggsave(file.path(FIG_DIR, "umap_celltypes.png"), p, width = 12, height = 6, dpi = 150)
```

Click the `.png` in VSCode's Explorer panel to view it.

---

## Step 12 — Set up conda (Python / Jupyter notebooks)

The Python side of the course uses a shared conda environment, not the container. From your compute node terminal (**exit the container first** if you're still inside it — type `exit`):

```bash
module load conda
conda activate /shared/projects/tp_2630_ubordeaux_neuromics_184418/envs/single_cell
```

This environment is maintained separately and already has `numpy`, `pandas`, `anndata`, `matplotlib`, and `jupyter` installed.

---

## Step 13 — Run the sample Jupyter notebook

Open `notebooks/python-kernel-check.ipynb` from your git checkout in VSCode.

1. Click **Select Kernel** (top-right of the notebook).
2. Choose **Select Another Kernel** → **Python Environments**.
3. If `single_cell` isn't listed automatically, choose **Enter interpreter path** and paste:
   ```
   /shared/projects/tp_2630_ubordeaux_neuromics_184418/envs/single_cell/bin/python
   ```
4. Click **Run All** (or run cells one at a time with `Shift+Enter`) to confirm the kernel works.

---

## Checking and cleaning up

```bash
# In a separate terminal on the login node:
squeue -u tp18XXXX      # list your running jobs
scancel <JOBID>         # cancel when done
```

Always cancel your job when finished — resources are shared across all groups.

---

## File locations

`$PROJ` is the shared project path you set in Step 6 (e.g. `/shared/projects/.../projects/C10`) — data only, uploaded day by day. `$GIT` is your git checkout path (e.g. `~/cajal-project-alan`) — code only.

| Path | Contents |
|---|---|
| `$GIT/` | Your git checkout (`GIT_DIR` in R) |
| `$GIT/notebooks/` | Course notebooks (`.qmd` and `.ipynb`) |
| `$GIT/setup-quarto-visualization.R` | Visualization setup script, sourced from `GIT_DIR` |
| `$PROJ/` | Your group's shared data folder (`PROJ_DIR` in R) |
| `$PROJ/data/` | Your group's data (`DATA_DIR` in R) |
| `$PROJ/figures/` | Your saved figures (`FIG_DIR` in R) |
| `/shared_project/data/shared_reference/` | Shared reference datasets |
| `/shared/projects/tp_2630_ubordeaux_neuromics_184418/envs/single_cell` | Shared Python conda env for Jupyter notebooks (maintained by another instructor) |
