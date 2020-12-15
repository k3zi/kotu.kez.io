import React from "react";
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed'
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import YouTube from 'react-youtube';

import DeleteProjectModal from "./DeleteProjectModal";
import CreateProjectModal from "./CreateProjectModal";

class Projects extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            showCreateProjectModal: false,
            showDeleteProjectModal: null,
            projects: []
        };
    }

    componentDidMount() {
        this.loadProjects();
    }

    async loadProjects() {
        const response = await fetch(`/api/transcription/projects`);
        if (response.ok) {
            const projects = await response.json();
            this.setState({ projects });
        }
    }

    toggleCreateProjectModal(show) {
        this.setState({
            showCreateProjectModal: show
        });
    }

    async showDeleteProjectModal(project) {
        this.setState({
            showDeleteProjectModal: project
        });
        await this.loadProjects();
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
                            <th className="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.state.projects.map(project => {
                            return (<tr>
                                <td className="align-middle">{project.name}</td>
                                <td className="align-middle">{project.translations.filter(t => t.isOriginal)[0].language.name}</td>
                                <td className="align-middle text-center">
                                    <LinkContainer to={`/transcription/${project.id}`}>
                                        <Button variant="primary"><i class="bi bi-arrow-right"></i></Button>
                                    </LinkContainer>
                                    {" "}
                                    <Button variant="danger" onClick={() => this.showDeleteProjectModal(project)}><i class="bi bi-trash"></i></Button>
                                </td>
                            </tr>)
                        })}
                    </tbody>
                </Table>

                <CreateProjectModal show={this.state.showCreateProjectModal} onHide={() => this.toggleCreateProjectModal(false)} />
                <DeleteProjectModal project={this.state.showDeleteProjectModal} didDelete={() => this.showDeleteProjectModal(null)} didCancel={() => this.showDeleteProjectModal(null)} onHide={() => this.showDeleteProjectModal(null)} />
            </div>
        )
    }
}

export default Projects;
