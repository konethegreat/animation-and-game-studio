import type { Project } from "../projects.generated";
import { bounceLabMarkup, mountBounceLab } from "./bounce";

export function labMarkup(project: Project): string {
  switch (project.interactive) {
    case "bounce":
      return bounceLabMarkup();
    default:
      return "";
  }
}

export function mountLab(project: Project, root: ParentNode = document): (() => void) | null {
  switch (project.interactive) {
    case "bounce": {
      const section = root.querySelector<HTMLElement>("#lab");
      return section ? mountBounceLab(section) : null;
    }
    default:
      return null;
  }
}
