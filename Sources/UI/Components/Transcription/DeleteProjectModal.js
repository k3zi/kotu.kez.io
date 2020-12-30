import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';
import YouTube from 'react-youtube';

class DeleteProjectModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            show: true
        };
    }

    async confirmDelete() {
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });
        const response = await fetch(`/api/transcription/project/${this.props.project.id}`, {
            method: 'DELETE'
        });
        const success = response.ok;
        this.setState({
            isSubmitting: false,
            success
        });

        if (success) {
            this.setState({ message: 'Deleted.'  });
            setTimeout(() => {
                this.props.didDelete();
            }, 2000);
        } else {
            const result = response.json();
            this.setState({
                didError: result.error,
                message: result.reason,
            });
        }
    }

    render() {
        return (
            <Modal {...this.props} show={this.props.project != null} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Confirm Deletion
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <p>Are you sure you wish to delete: {this.props.project ? this.props.project.name : ''}</p>
                </Modal.Body>
                <Modal.Footer>
                    {this.state.didError && <Alert variant="danger">
                        {this.state.message}
                    </Alert>}
                    {!this.state.didError && this.state.message && <Alert variant="info">
                        {this.state.message}
                    </Alert>}

                    {!this.state.success && <Button variant="secondary" disabled={this.state.isSubmitting} onClick={() => this.props.didCancel()}>Cancel</Button>}
                    {!this.state.success && <Button variant="danger" disabled={this.state.isSubmitting} onClick={() => this.confirmDelete()}>
                        {this.state.isSubmitting ? 'Deleting...' : 'Delete'}
                    </Button>}
                </Modal.Footer>
            </Modal>
        );
    }
}

export default DeleteProjectModal;
