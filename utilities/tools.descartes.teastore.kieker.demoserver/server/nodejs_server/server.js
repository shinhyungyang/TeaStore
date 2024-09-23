const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();

// Exposing the server on port 3000 internally in the container
const port = 3000;

// Make the app start at ./server.js so it detects html
app.use(express.static(path.join(__dirname, '/')));
app.use(express.json());

app.post('/generate-pdf', (req, res) => {
    const type = req.body.option;

    // Map graph type to shell script
    const scriptMap = {
        type1: path.join(__dirname, '../java/graph_scripts/deployment_op_dep.sh'),
        type2: path.join(__dirname, '../java/graph_scripts/agg_deployment_call_tree.sh'),
    };

    const scriptPath = scriptMap[type];

    // Check for invalid Path
    if (!scriptPath) {
      return res.status(400).send('Invalid option');
    }

    // Execute the shell script (Ensure the script is executed from its own directory instead of server.js dir)
    exec(`sh ${scriptPath}`, { cwd: path.join(__dirname, '../java/graph_scripts/') }, (error, stdout, stderr) => {
        if (error) {
            console.error(`exec command error: ${error}`);
            return res.status(500).send('Failed to generate Graph. exec Command Error');
        }

        const pdfPath = path.join(__dirname, '..', 'java', 'out', 'output_graph.pdf');

        // Check if the PDF exists and send it back
        if (fs.existsSync(pdfPath)) {
            res.set({
                'Content-Type': 'application/pdf',
                'Content-Disposition': `inline; filename=output_graph.pdf`,
            });
            fs.createReadStream(pdfPath).pipe(res);
        } else {
            res.status(500).send('Failed to generate Graph. PDF not found');
        };
    });
});

app.listen(port, () => {
    console.log(`Server listening on port ${port}`);
});
