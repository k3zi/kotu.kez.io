import React from "react";

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed'
import Row from 'react-bootstrap/Row';

class InviteUserModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            languages: []
        };
    }

    async componentDidMount() {
        const response = await fetch(`/api/settings/languages`);
        if (response.ok) {
            const languages = await response.json();
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
        const response = await fetch(`/api/transcription/project/${this.props.project.id}/invite/${data.username}`, {
            method: "POST"
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            isSubmitting: false,
            success
         });

         if (response.ok) {
             this.props.onFinish(result);
         } else {
             this.setState({
                 didError: result.error,
                 message: result.reason
              });
         }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Invite User to Edit Project
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="createProjectModalLanguage">
                            <Form.Label>Username to Invite</Form.Label>
                            <Form.Control name="username" placeholder="Enter username" />
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger">
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info">
                            {this.state.message}
                        </Alert>}

                        {!this.state.success && <Button variant="secondary" disabled={this.state.isSubmitting} onClick={() => this.props.didCancel()}>Cancel</Button>}
                        {" "}
                        {this.state.languages.length > 0 && !this.state.success && <Button variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Inviting...' : 'Invite'}
                        </Button>}
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }
}

export default InviteUserModal;
