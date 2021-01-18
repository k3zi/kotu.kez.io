import React from 'react';
import _ from 'underscore';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';

class EditDeckModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            requestedFI: null
        };
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        data.requestedFI = parseInt(data.requestedFI);
        const response = await fetch(`/api/flashcard/deck/${this.props.deck.id}`, {
            method: 'PUT',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            isSubmitting: false,
            didError: result.error,
            message: result.error ? result.reason : null,
            success
        });

        if (success) {
            this.props.onSuccess();
        }
    }

    requestedFI() {
        return this.state.requestedFI || this.props.deck.sm.requestedFI;
    }

    render() {
        return (
            <Modal {...this.props} show={!!this.props.deck} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Edit Deck
                    </Modal.Title>
                </Modal.Header>

                {this.props.deck && <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="editDeckModalName" className='mb-3'>
                            <Form.Label>Name</Form.Label>
                            <Form.Control defaultValue={this.props.deck.name} autoComplete="off" type="text" name="name" placeholder="Enter the name of the deck" />
                        </Form.Group>
                        <Form.Group controlId="editDeckModalRequestedFI" className='mb-3'>
                            <Form.Label>Forgetting Index</Form.Label>
                            <InputGroup>
                                <Form.Control name='requestedFI' value={this.requestedFI()} readOnly />
                                <Button variant="outline-secondary" onClick={() => this.setState({ requestedFI: Math.max(this.requestedFI() - 1, 3) })}>
                                    -
                                </Button>
                                <Button variant="outline-secondary" onClick={() => this.setState({ requestedFI: Math.min(this.requestedFI() + 1, 20) })}>
                                    +
                                </Button>
                            </InputGroup>
                        </Form.Group>

                        {this.state.didError && <Alert variant="danger" className='mb-3'>
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info" className='mb-3'>
                            {this.state.message}
                        </Alert>}

                        <Button className='col-12' variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Saving...' : 'Save'}
                        </Button>
                    </Form>
                </Modal.Body>}
            </Modal>
        );
    }
}

export default EditDeckModal;
