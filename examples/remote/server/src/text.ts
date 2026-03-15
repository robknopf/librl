import { rl_text_draw, rl_text_draw_ex, rl_text_measure, rl_text_measure_ex } from "./rl/rl_text";

export class Text {
  constructor(
    public value: string,
    public x: number,
    public y: number,
    public fontSize: number,
    public color: number,
    public font: number = 0,
    public spacing: number = 1.0,
  ) {}

  draw(): void {
    if (this.font !== 0) {
      rl_text_draw_ex(this.font, this.value, this.x, this.y, this.fontSize, this.spacing, this.color);
      return;
    }

    rl_text_draw(this.value, this.x, this.y, this.fontSize, this.color);
  }

  measure(): number {
    return rl_text_measure(this.value, this.fontSize);
  }

  measureEx(): { x: number; y: number } {
    return rl_text_measure_ex(this.font, this.value, this.fontSize, this.spacing);
  }
}
