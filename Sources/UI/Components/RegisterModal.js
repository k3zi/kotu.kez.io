import React from "react";

import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';

class RegisterModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            error: null
        };
    }

    async submit(event) {
        event.preventDefault();
        this.setState({ isSubmitting: true });
        const data = Object.fromEntries(new FormData(event.target));
        console.log(data);
        const res = await fetch(`/api/auth/register`, {
            method: "POST",
            body: JSON.stringify(data),
            headers: {
                "Content-Type": "application/json"
            }
        });
        this.setState({ isSubmitting: false });
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Register
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="registerModalUsername">
                            <Form.Label>Username</Form.Label>
                            <Form.Control type="text" name="username" placeholder="Enter a username" />
                        </Form.Group>

                      <Form.Group controlId="registerModalPassword">
                            <Form.Label>Password</Form.Label>
                            <Form.Control type="password" name="password" placeholder="Password" />
                      </Form.Group>
                      <Button variant="primary" type="submit">
                            Register
                      </Button>
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }

}

export default RegisterModal;
