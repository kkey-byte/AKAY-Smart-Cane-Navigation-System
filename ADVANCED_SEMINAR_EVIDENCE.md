# ADVANCE SEMINAR SERIES

## Members
Batulanon, Mariel Joyce  
Cadiao, Regine Kris  
Curato, Glaisa Mae

## Project
AKAY: A SMART CANE NAVIGATION SYSTEM WITH CAREGIVER MONITORING USING LIDAR SENSOR

GitHub repository: https://github.com/kkey-byte/AKAY-Smart-Cane-Navigation-System

## Overview
For this activity, we used our existing AKAY Flutter capstone project to organize information for AI-assisted development. We created a separate Git branch, prepared a project knowledge file, created two project-specific skills, and downloaded an external skill from Vercel. The screenshots to be inserted below document these artifacts.

## Step 1 - Create a new Git branch
We created the newskill1 branch from feature/yes_sir before adding the seminar files.

Screenshot: show the GitHub branch dropdown with newskill1 selected after publishing the branch. For local proof, show the terminal output of git branch --show-current.

GitHub location after publishing: https://github.com/kkey-byte/AKAY-Smart-Cane-Navigation-System/tree/newskill1

## Step 2 - Create knowledge.md
We created knowledge.md in the Flutter project root. It documents AKAY's purpose, mobile features, technologies, source structure, development guidelines, and seminar skills. It distinguishes mobile implementation from unverified LiDAR hardware integration.

Screenshot: open knowledge.md with the project root visible in VS Code Explorer, or open the file on GitHub after publishing.

GitHub location after publishing: https://github.com/kkey-byte/AKAY-Smart-Cane-Navigation-System/blob/newskill1/knowledge.md

## Step 3 - Create two custom skills
We created create-component for reusable AKAY Flutter widgets and add-api-call for HTTP service integration, each with a SKILL.md under .agents/skills/. These instructions refer to the existing Gabay theme, widgets, service layer, session handling, and verification practices.

Screenshots: expand both custom folders in Explorer and open each SKILL.md. Show the name, description, and project-specific instructions.

GitHub locations after publishing:
- https://github.com/kkey-byte/AKAY-Smart-Cane-Navigation-System/blob/newskill1/.agents/skills/create-component/SKILL.md
- https://github.com/kkey-byte/AKAY-Smart-Cane-Navigation-System/blob/newskill1/.agents/skills/add-api-call/SKILL.md

## Step 4 - Install a skill from a provider
We downloaded vercel-react-best-practices from the vercel-labs/agent-skills repository into .agents/skills/. Its frontmatter identifies Vercel as the author. This skill covers React and Next.js and satisfies the external-provider installation requirement; its framework-specific instructions are not intended for AKAY's Flutter code.

Provider source: https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices

Screenshot: show the installed folder and SKILL.md name, description, and author metadata. The provider source page alone does not prove a local installation.

GitHub location after publishing: https://github.com/kkey-byte/AKAY-Smart-Cane-Navigation-System/blob/newskill1/.agents/skills/vercel-react-best-practices/SKILL.md

## Capture instructions
Open C:\Users\Asus\app_mobile in VS Code. Show the Explorer and the relevant file side by side. Press Windows + Shift + S to capture each evidence view, then insert the images beneath the matching step in your submission document. For GitHub screenshots, publish the seminar commit first and verify each link above loads on newskill1. Never include credentials or personal user/location data.

## Scope of verification
Skill validation checks file structure and frontmatter; it does not prove app functionality. This activity changes documentation and skills, so it does not verify device GPS, live backend behavior, or LiDAR hardware. Existing app edits are outside the seminar commit.
