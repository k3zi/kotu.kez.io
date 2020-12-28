import React from "react";

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';

class CreateFieldModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false
        };
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        const response = await fetch(`/api/flashcard/noteType/${this.props.noteType.id}/field`, {
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
            message: result.error ? result.reason : 'Loading new field...',
            success
         });

         if (success) {
             this.props.onSuccess();
             this.setState({
                 success: false,
                 message: null,
                 didError: false
             });
         }
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Add Field
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="createFieldModalName">
                            <Form.Label>Name</Form.Label>
                            <Form.Control autoComplete="off" type="text" name="name" placeholder="Enter the name of the note field" />
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger">
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info">
                            {this.state.message}
                        </Alert>}

                        {!this.state.success && <Button variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Loading...' : 'Add +'}
                        </Button>}
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }
}

export default CreateFieldModal;
