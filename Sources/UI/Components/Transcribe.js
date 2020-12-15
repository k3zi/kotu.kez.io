import React from "react";

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Table from 'react-bootstrap/Table';

class CreateProjectModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            languages: [{
                id: 'test',
                name: 'ytest'
            }]
        };
    }

    async componentDidMount() {
        const response = await fetch(`/api/settings/languages`);
        if (response.ok) {
            const languages = await response.json();
            console.log(languages);
            this.setState({ languages });
        }
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        const response = await fetch(`/api/project/create`, {
            method: "POST",
            body: JSON.stringify(data),
            headers: {
                "Content-Type": "application/json"
            }
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            isSubmitting: false,
            didError: result.error,
            message: result.error ? result.reason : 'Logging in...',
            success
         });

         if (success) {
             setTimeout(() => {
                 location.reload();
             }, 3000);
         }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Create Project
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="createProjectModalName">
                            <Form.Label>Name</Form.Label>
                            <Form.Control type="text" name="name" placeholder="Enter the name of the project" />
                        </Form.Group>

                        <Form.Group controlId="createProjectModalYouTubeID">
                            <Form.Label>YouTube ID</Form.Label>
                            <Form.Control type="text" name="youtubeID" placeholder="Enter the ID of the YouTube video" />
                        </Form.Group>

                        <Form.Group controlId="createProjectModalLanguage">
                            <Form.Label>Language</Form.Label>
                            <Form.Control as="select" name="language" placeholder="Enter content original language" >
                                {this.state.languages.map(language => {
                                    return <option key={language.id} value={language.id}>{language.name}</option>
                                })}
                            </Form.Control>
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger">
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info">
                            {this.state.message}
                        </Alert>}

                        {this.state.languages.length > 0 && !this.state.success && <Button variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Loading...' : 'Create'}
                        </Button>}
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }

}

class Transcribe extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showCreateProjectModal: false,
            projects: []
        };
    }

    toggleCreateProjectModal(show) {
        this.setState({
            showCreateProjectModal: show
        })
    }

    render() {
        return (
            <div>
                <h1>Transcribe <small className="text-muted">{this.state.projects.length} Project(s)</small></h1>
                <Button variant="primary" onClick={() => this.toggleCreateProjectModal(true)}>Create Project</Button>
                <hr/>
                <Table striped bordered hover>
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Base Language</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>Mark</td>
                            <td>Otto</td>
                            <td>@mdo</td>
                        </tr>
                        <tr>
                            <td>Jacob</td>
                            <td>Thornton</td>
                            <td>@fat</td>
                        </tr>
                        <tr>
                            <td colSpan="2">Larry the Bird</td>
                            <td>@twitter</td>
                        </tr>
                    </tbody>
                </Table>

                <CreateProjectModal show={this.state.showCreateProjectModal} onHide={() => this.toggleCreateProjectModal(false)} />
            </div>
        )
    }
}

export default Transcribe;
