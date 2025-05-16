import argparse
import cairosvg
from pathlib import Path

def convert_image(image_path, output_path):
    cairosvg.svg2png(url=str(image_path), write_to=str(output_path), output_width=1200, output_height=600)

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--output_dir', type=str, required=True)
    return parser.parse_args()

def main():
    args = parse_args()
    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)
    for path in input_dir.glob('*.svg'):
        output_path = output_dir / (path.stem + '.png')
        convert_image(path, output_path)
        

if __name__ == '__main__':
    main()
