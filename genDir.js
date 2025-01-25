#!/usr/bin/env node
const fs = require('fs').promises;
const path = require('path');

async function parseStructureFile(filePath) {
    try {
        const content = await fs.readFile(filePath, 'utf8');
        const lines = content.split('\n');
        
        const rootDir = lines[0].replace('/', '');
        
        const pathStack = [];
        const structure = [];
        let prevDepth = -1;
        
        for (const line of lines.slice(1)) {
            if (!line.trim()) continue;
            
            const match = line.match(/^(│\s*├──\s*|│\s*└──\s*|├──\s*|└──\s*)(.*)/);
            if (!match) continue;
            
            const depth = (line.match(/│/g) || []).length;
            const name = match[2].trim();
            
            if (depth <= prevDepth) {
                while (pathStack.length > depth) {
                    pathStack.pop();
                }
            }
            
            if (depth === pathStack.length) {
                pathStack.push(name);
            } else {
                pathStack[depth] = name;
            }
            
            const fullPath = pathStack.slice(0, depth + 1).join('/');
            
            structure.push({
                depth,
                name,
                path: fullPath
            });
            
            prevDepth = depth;
        }
        
        return { rootDir, structure };
    } catch (error) {
        throw new Error(`Error parsing structure file: ${error.message}`);
    }
}

async function createDirectory(basePath, dirPath) {
    const fullPath = path.join(basePath, dirPath);
    try {
        await fs.mkdir(fullPath, { recursive: true });
    } catch (error) {
        if (error.code !== 'EEXIST') {
            throw new Error(`Error creating directory ${fullPath}: ${error.message}`);
        }
    }
}

async function createFile(basePath, filePath) {
    const fullPath = path.join(basePath, filePath);
    try {
        await fs.mkdir(path.dirname(fullPath), { recursive: true });
        await fs.writeFile(fullPath, '');
    } catch (error) {
        throw new Error(`Error creating file ${fullPath}: ${error.message}`);
    }
}

async function generateDirectoryStructure(structureFilePath, outputBasePath) {
    try {
        const { rootDir, structure } = await parseStructureFile(structureFilePath);
        const baseOutputPath = path.join(outputBasePath, rootDir);
        
        await createDirectory(outputBasePath, rootDir);
        
        for (const item of structure) {
            const isDirectory = item.name.endsWith('/') || 
                              (['src', 'test', 'benchmarks', 'examples', 'docs'].includes(item.name));
            
            if (isDirectory) {
                await createDirectory(baseOutputPath, item.path);
            } else {
                await createFile(baseOutputPath, item.path);
            }
        }
        
        console.log(`Successfully generated directory structure at: ${baseOutputPath}`);
    } catch (error) {
        console.error('Error generating directory structure:', error.message);
        process.exit(1);
    }
}

if (process.argv.length < 3) {
    console.error('Please provide the path to the structure file.');
    console.error('Usage: node genStructure.js <structure-file-path> [output-path]');
    process.exit(1);
}

const structureFilePath = process.argv[2];
const outputPath = process.argv[3] || process.cwd();

generateDirectoryStructure(structureFilePath, outputPath);