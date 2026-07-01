# Student Setup Guide — CAJAL Neuromics 2026

## Prerequisites

- Your IFB username (format: `tp18XXXX`)
- VSCode installed on your laptop with these extensions:
  - **Remote - SSH**
  - **R**
  - **Quarto**

---

## Step 1 — Connect to the cluster

Add this to your SSH config file:
- Mac/Linux: `~/.ssh/config`
- Windows: `C:\Users\<YourName>\.ssh\config`

```
Host ifb-neuromics
  HostName core-login2.cluster.france-bioinformatique.fr
  User tp18XXXX
```

In VSCode: open the Command Palette (`Ctrl+Shift+P`) → **Remote-SSH: Connect to Host** → select `ifb-neuromics`.

---

## Step 2 — Request a compute node

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

---

## Step 3 — Launch the container

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

## Step 4 — Start R

Inside the container, type:

```bash
R
```

---

## Step 5 — Create your figures folder

Run this once from inside the container (use the same path as `PROJ`):

```bash
mkdir -p $PROJ/figures
```

---

## Step 6 — Run the notebooks

Open any `.qmd` file from `$PROJ/notebooks/` in VSCode and click **Run Cell**.

In the **first setup cell**, set `PROJ_DIR` to your project path:

```r
PROJ_DIR <- "/shared/projects/tp_2630_ubordeaux_neuromics_184418/projects/C10"
```

VSCode sends each cell directly to the R session running in your terminal — inside the container, on your 128 GB compute node.

To render the full notebook to HTML:

```bash
quarto render notebook1.qmd
```

---

## Step 7 — View plots interactively (httpgd)

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

## Step 8 — Save plots to file

For plots you want to keep:

```r
p <- DimPlot(sci, group.by = "cell_type", ...)
ggsave(file.path(FIG_DIR, "umap_celltypes.png"), p, width = 12, height = 6, dpi = 150)
```

Click the `.png` in VSCode's Explorer panel to view it.

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

`$PROJ` is the path you set in step 3 (e.g. `/shared/projects/.../projects/C10`).

| Path | Contents |
|---|---|
| `$PROJ/` | Your group's working folder (`PROJ_DIR` in R) |
| `$PROJ/notebooks/` | Course notebooks |
| `$PROJ/data/` | Your group's data (`DATA_DIR` in R) |
| `$PROJ/figures/` | Your saved figures (`FIG_DIR` in R) |
| `/shared_project/data/shared_reference/` | Shared reference datasets |
