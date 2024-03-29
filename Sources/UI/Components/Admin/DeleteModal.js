import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import YouTube from 'react-youtube';

class DeleteDeckModal extends React.Component {

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
        const response = await fetch(this.props.url, {
            method: 'DELETE'
        });
        const success = response.ok;
        this.setState({
            isSubmitting: false,
            success
        });

        if (success) {
            this.props.onSuccess();
        } else {
            const result = await response.json();
            this.setState({
                didError: result.error,
                message: result.reason,
            });
        }
    }

    render() {
        return (
            <Modal {...this.props} show={!!this.props.object} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        {this.props.title}
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <p>{this.props.confirmationMessage}</p>
                </Modal.Body>
                <Modal.Footer>
                    {this.state.message && <Alert variant={this.state.didError ? 'danger' : 'info'} className='mb-3'>
                        {this.state.message}
                    </Alert>}

                    <Button variant='secondary' disabled={this.state.isSubmitting} onClick={() => this.props.onHide()}>Cancel</Button>
                    <Button variant='danger' disabled={this.state.isSubmitting} onClick={() => this.confirmDelete()}>
                        {this.state.isSubmitting ? 'Deleting...' : 'Delete'}
                    </Button>
                </Modal.Footer>
            </Modal>
        );
    }

}

export default DeleteDeckModal;
