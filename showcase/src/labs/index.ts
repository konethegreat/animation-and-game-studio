import type { Project } from "../projects.generated";
import { bounceLabMarkup, mountBounceLab } from "./bounce";
import { companionLabMarkup, mountCompanionLab } from "./companion";

export function labMarkup(project: Project): string {
  switch (project.interactive) {
    case "bounce":
      return bounceLabMarkup();
    case "companion":
      return companionLabMarkup(project);
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
    case "companion": {
      const section = root.querySelector<HTMLElement>("#lab");
      return section ? mountCompanionLab(section, project) : null;
    }
    default:
      return null;
  }
}
