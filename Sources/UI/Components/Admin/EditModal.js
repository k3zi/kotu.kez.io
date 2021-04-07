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
            success: false
        };
    }

    componentDidUpdate(prevProps) {
        if (this.props.object != prevProps.object) {
            this.setState({ object: this.props.object });
        }
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        const response = await fetch(this.props.url, {
            method: 'PUT',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        this.setState({
            isSubmitting: false,
            success: response.ok
        });

        if (response.ok) {
            this.props.onSuccess();
            this.setState({
                didError: false,
                message: null
            });
        } else {
            const result = await response.json();
            this.setState({
                didError: result.error,
                message: result.error ? result.reason : null
            });
        }
    }

    render() {
        return (
            <Modal {...this.props} show={!!this.props.object} size='lg' centered>
                <Modal.Header closeButton>
                    <Modal.Title>
                        {this.props.title}
                    </Modal.Title>
                </Modal.Header>

                {this.state.object && this.props.fields && <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        {this.props.fields.map(field => {
                            if (field.type === 'text') {
                                return (
                                    <Form.Group className='mb-3'>
                                        <Form.Label>{field.label}</Form.Label>
                                        <Form.Control defaultValue={this.state.object[field.name]} autoComplete='off' type='text' name={field.name} placeholder={field.placeholder} />
                                    </Form.Group>
                                );
                            }
                        })}

                        {this.state.message && <Alert variant={this.state.didError ? 'danger' : 'info'} className='mb-3'>
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
