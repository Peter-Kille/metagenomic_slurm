#!/usr/bin/env python3
"""Summarise kraken2 reports across stringency (--confidence) levels.

Expects <kraken_dir>/conf<level>/<sample>.kraken.report (as written by 3B-kraken_array.sh).
Writes one row per (level, sample) with classification rate, reads resolved to species/genus,
taxon richness at a minimum read count, domain composition, and the species-set Jaccard
similarity to the least stringent level. Use it to see where the curves plateau and
(with blanks / mock communities flagged) where false positives drop out.
"""
import argparse
import glob
import os
import re


def parse_report(path):
    d = {'total': 0, 'unclassified': 0, 'species': {}, 'genera': {}, 'domains': {}}
    with open(path) as fh:
        for line in fh:
            f = line.rstrip('\n').split('\t')
            if len(f) < 6:
                continue
            clade, rank, name = int(f[1]), f[3], f[5].strip()
            if rank == 'U':
                d['unclassified'] = clade
                d['total'] += clade
            elif rank == 'R':
                d['total'] += clade
            elif rank == 'D':
                d['domains'][name] = clade
            elif rank == 'S':
                d['species'][name] = clade
            elif rank == 'G':
                d['genera'][name] = clade
    return d


def level_key(p):
    return float(re.search(r'conf([0-9.]+)$', p).group(1))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('-d', '--kraken_dir', required=True)
    ap.add_argument('-o', '--output', required=True)
    ap.add_argument('-m', '--min_reads', type=int, default=10,
                    help='clade reads for a taxon to count towards richness (default 10)')
    a = ap.parse_args()

    levels = sorted(glob.glob(os.path.join(a.kraken_dir, 'conf*')), key=level_key)
    domains = ['Bacteria', 'Archaea', 'Eukaryota', 'Viruses']
    base = {}
    rows = []
    for lv in levels:
        conf = os.path.basename(lv)[4:]
        for rep in sorted(glob.glob(os.path.join(lv, '*.kraken.report'))):
            sample = os.path.basename(rep)[:-len('.kraken.report')]
            r = parse_report(rep)
            tot = r['total'] or 1
            sp = {k for k, v in r['species'].items() if v >= a.min_reads}
            base.setdefault(sample, sp)  # first (least stringent) level is the baseline
            jac = len(sp & base[sample]) / len(sp | base[sample]) if (sp | base[sample]) else 1.0
            rows.append([conf, sample, r['total'], r['total'] - r['unclassified'],
                         round(100.0 * (r['total'] - r['unclassified']) / tot, 2),
                         sum(r['species'].values()), sum(r['genera'].values()),
                         len(r['species']), len(sp),
                         sum(1 for v in r['genera'].values() if v >= a.min_reads),
                         round(jac, 3)] + [r['domains'].get(x, 0) for x in domains])

    hdr = ['confidence', 'sample', 'total_reads', 'classified_reads', 'pct_classified',
           'reads_at_species', 'reads_at_genus', 'n_species_any', 'n_species_min%d' % a.min_reads,
           'n_genera_min%d' % a.min_reads, 'species_jaccard_vs_lowest'] + ['reads_' + x for x in domains]
    with open(a.output, 'w') as out:
        out.write('\t'.join(hdr) + '\n')
        for r in rows:
            out.write('\t'.join(str(x) for x in r) + '\n')


if __name__ == '__main__':
    main()