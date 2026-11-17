"""Build landscape vector figures for slides 8 and 10.

Run with the replication Python environment from any directory. Reuses
Data Analysis/didplots.py for all bins, fitted lines, and regression estimates.
Only the presentation layout changes; Figures/ retains the paper-style PDFs.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / 'Python' / 'Data Analysis'))
import didplots as plots


def main():
    data = plots.load_data()
    specs, _ = plots.run_regressions(data)
    destination = ROOT / 'figures' / 'replication'
    destination.mkdir(parents=True, exist_ok=True)
    with plots.plt.rc_context({'pdf.fonttype': 42}):
        for name, fe in [('fig_1_slides', None), ('fig_a4_slides', 'cs')]:
            fig = plots.plt.figure(figsize=(10.5, 5.8))
            for index, (panel, letter) in enumerate(zip(plots.BYSTANDER, 'ABCD')):
                col, row = index % 2, index // 2
                ax = fig.add_axes([0.075 + col * 0.50,
                                   0.63 if row == 0 else 0.14,
                                   0.405, 0.24])
                spec = specs[panel]
                plots.draw_panel(ax, spec['data'], spec, fe, letter)
                destination_label = ['US', 'China', 'RW', 'RW'][index]
                ax.set_title(f'Panel {letter}: exports to {destination_label}',
                             fontsize=14, fontweight='bold', pad=24)
                ax.xaxis.label.set_fontsize(13)
                ax.yaxis.label.set_fontsize(13)
                ax.tick_params(labelsize=12)
                for line in ax.lines:
                    line.set_linewidth(1.3)
                for collection in ax.collections:
                    collection.set_sizes([21])
                ax.legend(loc='lower center', bbox_to_anchor=(0.5, 1.0),
                          ncol=2, frameon=False, fontsize=11,
                          handletextpad=0.2, borderaxespad=0.2)
                b0, se0 = spec['res'][(0, fe is not None)][:2]
                b1, se1 = spec['res'][(1, fe is not None)][:2]
                annotation = ax.texts[0]
                annotation.set_text(f'Pre: {b0:.2f} ({se0:.2f})     '
                                    f'Post: {b1:.2f} ({se1:.2f})')
                annotation.set_fontsize(11)
                annotation.set_position((0, -0.43))
            fig.savefig(destination / f'{name}.pdf')
            plots.plt.close(fig)
            print(f'Saved {name}.pdf')


if __name__ == '__main__':
    main()
