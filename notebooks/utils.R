suppressPackageStartupMessages({
    library(splatter)
    library(scuttle)
})

simulate_counts_naive = function(model = c("poisson", "gaussian", "nb"),
    n_genes = 500, n_cells = 200, mu = 5, size = 1) {
    model = match.arg(model)
    mat = switch(model,
        poisson = matrix(
            rpois(n_genes * n_cells, lambda = mu),
            nrow = n_genes, ncol = n_cells
        ),
        gaussian = matrix(
            pmax(0L, round(rnorm(n_genes * n_cells, mean = mu, sd = sqrt(mu)))),
            nrow = n_genes, ncol = n_cells
        ),
        nb = matrix(
            rnbinom(n_genes * n_cells, size = size, mu = mu),
            nrow = n_genes, ncol = n_cells
        )
    )
    rownames(mat) = paste0("Gene", seq_len(n_genes))
    colnames(mat) = paste0("Cell", seq_len(n_cells))
    mat
}

simulate_counts = function(n_genes = 1000, n_cells = 500,
    de_prob = 0.1, de_fc = 2,
    n_samples = 6, replicate_effect = 0.1,
    batch_effect = 0.2,
    seed = 42) {

    set.seed(seed)
    n_per_group = n_samples %/% 2
    cells_per_sample = ceiling(n_cells / n_samples)
    gene_names = paste0("Gene", seq_len(n_genes))

    # Simulate all cells as a single group with batch effects.
    # batch.facLoc > 0 means each batch has a random multiplicative shift on
    # gene means — this is the within-replicate correlation that Wilcoxon ignores.
    params = newSplatParams(
        nGenes = n_genes,
        batchCells = rep(cells_per_sample, n_samples),
        batch.facLoc = batch_effect,
        batch.facScale = if (batch_effect > 0) 0.1 else 0,
        seed = seed
    )
    sim = splatSimulate(params, method = "single", verbose = FALSE)
    cts = counts(sim)
    rownames(cts) = gene_names
    meta = as.data.frame(colData(sim))

    # Assign first n_per_group batches to Group1, the rest to Group2.
    # This confounds replicate with condition — identical to real scRNA-seq
    # where each animal belongs to exactly one condition.
    batch_id = as.integer(sub("Batch", "", meta$Batch))
    meta$label = ifelse(batch_id <= n_per_group, "Group1", "Group2")

    # Choose DE genes and apply fold change to Group2 cells
    de_gene_names = character(0)
    if (de_prob > 0) {
        de_idx = sample(seq_len(n_genes), size = round(n_genes * de_prob))
        de_gene_names = gene_names[de_idx]
        g2_cells = which(meta$label == "Group2")
        orig_totals = colSums(cts[, g2_cells])
        cts[de_idx, g2_cells] = matrix(
            rnbinom(length(de_idx) * length(g2_cells),
                size = 20,
                mu = as.numeric(cts[de_idx, g2_cells]) * de_fc),
            nrow = length(de_idx)
        )
        new_totals = colSums(cts[, g2_cells])
        cts[, g2_cells] = round(sweep(cts[, g2_cells], 2, orig_totals / new_totals, "*"))
    }

    # Downsample sequencing depth per replicate
    if (replicate_effect > 0 && n_samples > 1) {
        batches = paste0("Batch", seq_len(n_samples))
        depth_vector = 1 - replicate_effect * seq_len(n_samples) + replicate_effect
        depth_vector = pmax(sample(depth_vector), 0.01)
        names(depth_vector) = batches
        cts = as.matrix(cts)
        for (b in batches) {
            idx = which(meta$Batch == b)
            cts[, idx] = as.matrix(scuttle::downsampleMatrix(
                cts[, idx, drop = FALSE], depth_vector[b]))
        }
    }

    names(meta)[names(meta) == "Batch"] = "replicate"

    list(
        counts = cts,
        metadata = meta,
        de_genes = de_gene_names
    )
}

compute_prc = function(scores, labels) {
    ord = order(scores, decreasing = TRUE)
    lab = labels[ord]
    tp = cumsum(lab)
    fp = cumsum(1 - lab)
    data.frame(precision = tp / (tp + fp), recall = tp / sum(labels))
}

auprc = function(prc) {
    r = c(0, prc$recall)
    p = c(1, prc$precision)
    sum(diff(r) * (p[-length(p)] + p[-1]) / 2)
}

compute_logfc = function(sim) {
    g1 = sim$metadata$label == "Group1"
    g2 = sim$metadata$label == "Group2"
    lfc = log2(
        rowMeans(sim$counts[, g2, drop = FALSE] + 1) /
        rowMeans(sim$counts[, g1, drop = FALSE] + 1)
    )
    data.frame(
        gene = names(lfc),
        logFC = lfc,
        is_de = names(lfc) %in% sim$de_genes
    )
}
